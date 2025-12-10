// worker.c
#include "worker.h"
#include "shared_mem.h"
#include "semaphores.h"
#include "config.h"
#include "thread_pool.h"
#include "stats.h"
#include "cache.h"
#include "http.h"
#include "logger.h"


#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <errno.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <string.h>
#include <sys/socket.h>



//all the global variables
shared_data_t* g_shared;
semaphores_t* g_sems;
file_cache_t* g_cache;

static char g_document_root[256] = {0};



// CONSUMER: gets a client_fd from the shared circular buffer
static int dequeue_connection(shared_data_t* data, semaphores_t* sems) {
    int client_fd;

    // Wait until there is at least one filled slot
    sem_wait(sems->filled_slots);
    sem_wait(sems->queue_mutex);

    //read from the circular buffer
    client_fd = data->queue.sockets[data->queue.front];
    data->queue.front = (data->queue.front + 1) % MAX_QUEUE_SIZE;
    data->queue.count--;

    sem_post(sems->queue_mutex);
    sem_post(sems->empty_slots); //signal that there is one more empty slot

    return client_fd;
}



void handle_client(int client_fd, shared_data_t* shared, semaphores_t* sems) {
    // --- Load document root from config (once) ---
    static char document_root[256] = {0};
    if (document_root[0] == '\0') {
        FILE* f = fopen("config.cfg", "r");
        if (f) {
            char line[256];
            while (fgets(line, sizeof(line), f)) {
                if (strncmp(line, "DOCUMENT_ROOT=", 14) == 0) {
                    strncpy(document_root, line + 14, sizeof(document_root) - 1);
                    // strip trailing newline or carriage return if present
                    size_t len = strlen(document_root);
                    if (len > 0 && (document_root[len - 1] == '\n' || document_root[len - 1] == '\r')) {
                        document_root[len - 1] = '\0';
                    }
                }
            }
            fclose(f);
        } else {
            strcpy(document_root, "./www");
        }
    }

    // --- Track active connections ---
    stats_increment_active(shared, sems);

    // --- Read HTTP request ---
    char buffer[2048] = {0};
    ssize_t rlen = recv(client_fd, buffer, sizeof(buffer) - 1, 0);
    if (rlen <= 0) {
        printf("[DEBUG] recv() failed: rlen=%zd, errno=%d\n", rlen, errno);
        stats_decrement_active(shared, sems);
        return;
    }
    buffer[rlen] = '\0';
    printf("[DEBUG] Received %zd bytes: %s\n", rlen, buffer);

    // --- Parse HTTP request ---
    http_request_t req;
    if (parse_http_request(buffer, &req) != 0) {
        printf("[DEBUG] parse_http_request FAILED\n");
        const char err_msg[] = "Malformed HTTP request\n";
        send_http_response(client_fd, 400, "Bad Request", "text/plain", err_msg, strlen(err_msg));
        stats_record_response(shared, sems, 400, strlen(err_msg));
        stats_decrement_active(shared, sems);
        return;
    }
    printf("[DEBUG] Parsed request: method=%s path=%s version=%s\n", req.method, req.path, req.version);

    // --- Only support GET ---
    if (strcmp(req.method, "GET") != 0) {
        const char err_msg[] = "Only GET supported\n";
        send_http_response(client_fd, 405, "Method Not Allowed", "text/plain", err_msg, strlen(err_msg));
        stats_record_response(shared, sems, 405, strlen(err_msg));
        stats_decrement_active(shared, sems);
        return;
    }

    // --- Prevent directory traversal ---
    if (strstr(req.path, "..")) {
        const char err_msg[] = "Forbidden path\n";
        send_http_response(client_fd, 403, "Forbidden", "text/plain", err_msg, strlen(err_msg));
        stats_record_response(shared, sems, 403, strlen(err_msg));
        stats_decrement_active(shared, sems);
        return;
    }

    // --- Build file path ---
    char file_path[1024];
    // Support directory index
    if (strcmp(req.path, "/") == 0 || req.path[strlen(req.path)-1] == '/') {
        snprintf(file_path, sizeof(file_path), "%s%sindex.html", document_root, req.path);
    } else {
        snprintf(file_path, sizeof(file_path), "%s/%s", document_root, req.path[0] == '/' ? req.path+1 : req.path);
    }
    // Truncation check
    if (strlen(file_path) >= sizeof(file_path)) {
        printf("[DEBUG] Path too long, aborting\n");
        const char msg[] = "404 Not Found\n";
        send_http_response(client_fd, 404, "Not Found", "text/plain", msg, strlen(msg));
        stats_record_response(shared, sems, 404, strlen(msg));
        stats_decrement_active(shared, sems);
        return;
    }
    printf("[DEBUG] Full file path: %s\n", file_path);

    // --- Try to open and read file ---
    FILE* fp = fopen(file_path, "rb");
    if (!fp) {
        printf("[DEBUG] File not found: %s\n", file_path);
        const char msg[] = "404 Not Found\n";
        send_http_response(client_fd, 404, "Not Found", "text/plain", msg, strlen(msg));
        stats_record_response(shared, sems, 404, strlen(msg));
        stats_decrement_active(shared, sems);
        return;
    }
    // Check file permissions (403 if unreadable)
    if (access(file_path, R_OK) != 0) {
        printf("[DEBUG] File not readable: %s\n", file_path);
        const char msg[] = "403 Forbidden\n";
        send_http_response(client_fd, 403, "Forbidden", "text/plain", msg, strlen(msg));
        stats_record_response(shared, sems, 403, strlen(msg));
        fclose(fp);
        stats_decrement_active(shared, sems);
        return;
    }

    // Get file size
    fseek(fp, 0, SEEK_END);
    size_t sz = (size_t)ftell(fp);
    fseek(fp, 0, SEEK_SET);

    if (sz == 0 || sz > 16 * 1024 * 1024) { // arbitrary cap for demo
        printf("[DEBUG] File too large or error: %zu\n", sz);
        const char msg[] = "500 Internal Error\n";
        send_http_response(client_fd, 500, "Internal Server Error", "text/plain", msg, strlen(msg));
        stats_record_response(shared, sems, 500, strlen(msg));
        fclose(fp);
        stats_decrement_active(shared, sems);
        return;
    }

    char *contents = malloc(sz);
    if (!contents) {
        printf("[DEBUG] Out of memory reading file\n");
        const char msg[] = "500 Internal Error\n";
        send_http_response(client_fd, 500, "Internal Server Error", "text/plain", msg, strlen(msg));
        stats_record_response(shared, sems, 500, strlen(msg));
        fclose(fp);
        stats_decrement_active(shared, sems);
        return;
    }
    size_t got = fread(contents, 1, sz, fp);
    fclose(fp);

    if (got != sz) {
        printf("[DEBUG] fread failed: read %zu bytes, expected %zu\n", got, sz);
        const char msg[] = "500 Internal Error\n";
        send_http_response(client_fd, 500, "Internal Server Error", "text/plain", msg, strlen(msg));
        stats_record_response(shared, sems, 500, strlen(msg));
        free(contents);
        stats_decrement_active(shared, sems);
        return;
    }

    // Determine MIME type (improve as needed)
    const char* mime = "text/html";
    const char* ext = strrchr(file_path, '.');
    if (ext && strcasecmp(ext, ".html") == 0) mime = "text/html";
    else if (ext && strcasecmp(ext, ".css") == 0) mime = "text/css";
    else if (ext && strcasecmp(ext, ".js") == 0) mime = "application/javascript";
    else if (ext && (strcasecmp(ext, ".jpg") == 0 || strcasecmp(ext, ".jpeg") == 0)) mime = "image/jpeg";
    else if (ext && strcasecmp(ext, ".png") == 0) mime = "image/png";
    else if (ext && strcasecmp(ext, ".txt") == 0) mime = "text/plain";

    send_http_response(client_fd, 200, "OK", mime, contents, sz);
    stats_record_response(shared, sems, 200, sz);
    free(contents);

    stats_decrement_active(shared, sems);
    printf("[DEBUG] Response sent, connection fd closed\n");
}



void run_worker_process(int listen_fd,
                        shared_data_t* shared,
                        semaphores_t* sems,
                        const server_config_t* config) {
    // Set global pointers for worker threads
    g_shared = shared;
    g_sems = sems;

    // Set document root
    strncpy(g_document_root, config->document_root, sizeof(g_document_root)-1);
    // Create the file cache
    size_t cache_bytes = 10 * 1024 * 1024;//default the 10MB if cant read from config
    if (config->cache_size_mb > 0) cache_bytes = config->cache_size_mb * 1024 * 1024;
    g_cache = cache_create(cache_bytes);
    if (!g_cache) {
        perror("Couldnt create cache");
        exit(EXIT_FAILURE);
    }

    // Create thread pool
    int nthreads = (config->threads_per_worker > 0) ? config->threads_per_worker : 10;
    thread_pool_t* pool = create_thread_pool(nthreads);
    
    if (!pool) {
        perror("Couldnt create thread pool");
        return;
    }

    // In prefork model: accept connections directly on the inherited listen_fd
    struct sockaddr_in client_addr;
    socklen_t client_len = sizeof(client_addr);
    while (1) {
        int client_fd = accept(listen_fd, (struct sockaddr*)&client_addr, &client_len);
        if (client_fd < 0) {
            if (errno == EINTR) continue;
            perror("accept");
            continue;
        }
        thread_addFd(pool, client_fd);
    }

   //cleanup
    destroy_thread_pool(pool);
}
