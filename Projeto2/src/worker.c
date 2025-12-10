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

//helper to get file type
const char* get_mime_type(const char* file_path) {
    const char* ext = strrchr(file_path, '.');
    if (!ext) return "application/octet-stream";
    if (strcasecmp(ext, ".html") == 0) return "text/html";
    else if (strcasecmp(ext, ".css") == 0) return "text/css";
    else if (strcasecmp(ext, ".js") == 0) return "application/javascript";
    else if (strcasecmp(ext, ".json") == 0) return "application/json";
    else if (strcasecmp(ext, ".jpg") == 0 || strcasecmp(ext, ".jpeg") == 0) return "image/jpeg";
    else if (strcasecmp(ext, ".png") == 0) return "image/png";
    else if (strcasecmp(ext, ".gif") == 0) return "image/gif";
    else if (strcasecmp(ext, ".svg") == 0) return "image/svg+xml";
    else if (strcasecmp(ext, ".txt") == 0) return "text/plain";
    else if (strcasecmp(ext, ".ico") == 0) return "image/x-icon";
    return "application/octet-stream";
}

// Helper to send a custom HTML error page if available, fallback to plain text if not
void send_custom_error_page(int client_fd, int status, const char* status_msg,
                            const char* document_root, const char* error_filename,
                            const char* fallback_msg, shared_data_t *shared, semaphores_t *sems) {
    char error_file_path[512];
    snprintf(error_file_path, sizeof(error_file_path), "%s/errors/%s", document_root, error_filename);
    FILE* fp = fopen(error_file_path, "rb");
    if (fp) {
        fseek(fp, 0, SEEK_END);
        size_t sz = (size_t)ftell(fp);
        fseek(fp, 0, SEEK_SET);
        char *contents = malloc(sz);
        if (contents && fread(contents, 1, sz, fp) == sz) {
            send_http_response(client_fd, status, status_msg, "text/html", contents, sz);
            stats_record_response(shared, sems, status, sz);
            free(contents);
            fclose(fp);
            return;
        }
        if (contents) free(contents);
        fclose(fp);
    }
    // Fallback: plain text error message
    send_http_response(client_fd, status, status_msg, "text/plain", fallback_msg, strlen(fallback_msg));
    stats_record_response(shared, sems, status, strlen(fallback_msg));
}

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
        send_custom_error_page(client_fd, 400, "Bad Request", document_root, "error400.html", "400 Bad Request\n", shared, sems);
        stats_decrement_active(shared, sems);
        return;
    }
    printf("[DEBUG] Parsed request: method=%s path=%s version=%s\n", req.method, req.path, req.version);

    // --- Only support GET and HEAD ---
    int is_head = 0;
    if (strcmp(req.method, "GET") == 0) {
        is_head = 0;
    } else if (strcmp(req.method, "HEAD") == 0) {
        is_head = 1;
    } else {
        send_custom_error_page(client_fd, 405, "Method Not Allowed", document_root, "error405.html", "405 Method Not Allowed\n", shared, sems);
        stats_decrement_active(shared, sems);
        return;
    }

    // --- Prevent directory traversal ---
    if (strstr(req.path, "..")) {
        send_custom_error_page(client_fd, 403, "Forbidden", document_root, "error403.html", "403 Forbidden\n", shared, sems);
        stats_decrement_active(shared, sems);
        return;
    }

    // --- Special URL to trigger 500 error for testing purposes ---
    // This allows you to verify 500 error handling from your test script.
    if (strcmp(req.path, "/trigger_500") == 0) {
        printf("[DEBUG] Triggered 500 Internal Server Error for testing\n");
        send_custom_error_page(client_fd, 500, "Internal Server Error", document_root, "error500.html", "500 Internal Server Error\n", shared, sems);
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
        send_custom_error_page(client_fd, 404, "Not Found", document_root, "error404.html", "404 Not Found\n", shared, sems);
        stats_decrement_active(shared, sems);
        return;
    }
    printf("[DEBUG] Full file path: %s\n", file_path);

    // --- Check file permissions (403 if unreadable) ---
    if (access(file_path, R_OK) != 0) {
        // File exists but is not readable
        if (access(file_path, F_OK) == 0) {
            printf("[DEBUG] File not readable: %s\n", file_path);
            send_custom_error_page(client_fd, 403, "Forbidden", document_root, "error403.html", "403 Forbidden\n", shared, sems);
            stats_decrement_active(shared, sems);
            return;
        }
    }

    // --- Try to open and read file ---
    FILE* fp = fopen(file_path, "rb");
    if (!fp) {
        printf("[DEBUG] File not found: %s\n", file_path);
        send_custom_error_page(client_fd, 404, "Not Found", document_root, "error404.html", "404 Not Found\n", shared, sems);
        stats_decrement_active(shared, sems);
        return;
    }

    // Get file size
    fseek(fp, 0, SEEK_END);
    size_t sz = (size_t)ftell(fp);
    fseek(fp, 0, SEEK_SET);

    if (sz == 0 || sz > 16 * 1024 * 1024) { // arbitrary cap for demo
        printf("[DEBUG] File too large or error: %zu\n", sz);
        send_custom_error_page(client_fd, 500, "Internal Server Error", document_root, "error500.html", "500 Internal Server Error\n", shared, sems);
        fclose(fp);
        stats_decrement_active(shared, sems);
        return;
    }

    char *contents = NULL;
    if (!is_head) {
        contents = malloc(sz);
        if (!contents) {
            printf("[DEBUG] Out of memory reading file\n");
            send_custom_error_page(client_fd, 500, "Internal Server Error", document_root, "error500.html", "500 Internal Server Error\n", shared, sems);
            fclose(fp);
            stats_decrement_active(shared, sems);
            return;
        }
        size_t got = fread(contents, 1, sz, fp);
        if (got != sz) {
            printf("[DEBUG] fread failed: read %zu bytes, expected %zu\n", got, sz);
            send_custom_error_page(client_fd, 500, "Internal Server Error", document_root, "error500.html", "500 Internal Server Error\n", shared, sems);
            free(contents);
            fclose(fp);
            stats_decrement_active(shared, sems);
            return;
        }
    }
    fclose(fp);

    // Determine MIME type using helper
    const char* mime = get_mime_type(file_path);

    // --- Now pass the correct MIME type in the 200 OK response! ---
    if (is_head) {
        send_http_response(client_fd, 200, "OK", mime, NULL, sz); // body=NULL, length is still needed for Content-Length
        stats_record_response(shared, sems, 200, sz);
    } else {
        send_http_response(client_fd, 200, "OK", mime, contents, sz);
        stats_record_response(shared, sems, 200, sz);
        free(contents);
    }

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