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

// added for debugging (copilot made)
static void get_client_ip(int client_fd, char* ip_buf, size_t buflen) {
    struct sockaddr_in addr;
    socklen_t addr_len = sizeof(addr);
    if (getpeername(client_fd, (struct sockaddr*)&addr, &addr_len) == 0) {
        inet_ntop(AF_INET, &addr.sin_addr, ip_buf, buflen);
    } else {
        strncpy(ip_buf, "127.0.0.1", buflen);
    }
}

//helper to get the type of file
static const char* get_mime_type(const char* filename) {
    const char* ext = strrchr(filename, '.');
    if (!ext) return "application/octet-stream";
    ext++;
    if (strcasecmp(ext, "html") == 0) return "text/html";
    if (strcasecmp(ext, "txt") == 0) return "text/plain";
    if (strcasecmp(ext, "css") == 0) return "text/css";
    if (strcasecmp(ext, "js") == 0)  return "application/javascript";
    if (strcasecmp(ext, "png") == 0) return "image/png";
    return "application/octet-stream";
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
    static char document_root[256] = {0};
    if (document_root[0] == '\0') {
        // Load from config file's DOCUMENT_ROOT *once* per worker process
        FILE* f = fopen("config.cfg", "r");
        if (f) {
            char line[256];
            while (fgets(line, sizeof(line), f)) {
                if (strncmp(line, "DOCUMENT_ROOT=", 14) == 0) {
                    strncpy(document_root, line + 14, sizeof(document_root)-1);
                    size_t len = strlen(document_root);
                    if (len && document_root[len-1] == '\n') document_root[len-1] = '\0';
                }
            }
            fclose(f);
        } else {
            strcpy(document_root, "./www"); // fallback
        }
    }

    stats_increment_active(shared, sems);

    char buffer[2048] = {0};

    ssize_t rlen = recv(client_fd, buffer, sizeof(buffer)-1, 0);
    if (rlen <= 0) {
        stats_decrement_active(shared, sems);
        return;
    }

    http_request_t req;
    if (parse_http_request(buffer, &req) != 0) {
        const char err_msg[] = "Malformed HTTP request\n";
        send_http_response(client_fd, 400, "Bad Request", "text/plain", err_msg, strlen(err_msg));
        stats_record_response(shared, sems, 400, strlen(err_msg));
        char client_ip[64] = {0};
        get_client_ip(client_fd, client_ip, sizeof(client_ip));
        log_request(sems->log_mutex, client_ip, "GET", "-", 400, strlen(err_msg));
        stats_decrement_active(shared, sems);
        return;
    }

    if (strcmp(req.method, "GET") != 0) {
        const char err_msg[] = "Only GET supported\n";
        send_http_response(client_fd, 405, "Method Not Allowed", "text/plain", err_msg, strlen(err_msg));
        stats_record_response(shared, sems, 405, strlen(err_msg));
        char client_ip[64] = {0};
        get_client_ip(client_fd, client_ip, sizeof(client_ip));
        log_request(sems->log_mutex, client_ip, req.method, req.path, 405, strlen(err_msg));
        stats_decrement_active(shared, sems);
        return;
    }

    if (strstr(req.path, "..")) {
        const char err_msg[] = "Forbidden path\n";
        send_http_response(client_fd, 403, "Forbidden", "text/plain", err_msg, strlen(err_msg));
        stats_record_response(shared, sems, 403, strlen(err_msg));
        char client_ip[64] = {0};
        get_client_ip(client_fd, client_ip, sizeof(client_ip));
        log_request(sems->log_mutex, client_ip, req.method, req.path, 403, strlen(err_msg));
        stats_decrement_active(shared, sems);
        return;
    }

    // Directory index support
    char file_path[600];
    if (strcmp(req.path, "/") == 0 || req.path[strlen(req.path) - 1] == '/') {
        snprintf(file_path, sizeof(file_path), "%sindex.html", req.path+1);
    } else {
        snprintf(file_path, sizeof(file_path), "%s", req.path+1);
    }

    size_t file_size = 0;
    unsigned char* file_data = cache_get(g_cache, file_path, &file_size);


    if (!file_data || file_size == 0) {
        // Try to load from disk
        char disk_path[1024];
        snprintf(disk_path, sizeof(disk_path), "%s/%s", document_root, file_path);
        FILE* fp = fopen(disk_path, "rb");
        if (fp) {
            fseek(fp, 0, SEEK_END);
            long sz = ftell(fp);
            fseek(fp, 0, SEEK_SET);
            if (sz > 0 && sz <= MAX_CACHE_FILE_SIZE) {
                unsigned char* buf = malloc(sz);
                if (buf && fread(buf, 1, sz, fp) == (size_t)sz) {
                    cache_put(g_cache, file_path, buf, sz);
                    file_data = buf;
                    file_size = sz;
                } else {
                    free(buf);
                }
            } else if (sz > 0) { // file too big to cache
                file_data = malloc(sz);
                if (file_data && fread(file_data, 1, sz, fp) == (size_t)sz) {
                    file_size = sz;
                } else {
                    free(file_data);
                    file_data = NULL;
                }
            }
            fclose(fp);
        }
    }

    if (file_data && file_size > 0) {
        const char* content_type = get_mime_type(file_path);
        send_http_response(client_fd, 200, "OK", content_type, (const char*)file_data, file_size);
        stats_record_response(shared, sems, 200, file_size);
        char client_ip[64] = {0};
        get_client_ip(client_fd, client_ip, sizeof(client_ip));
        log_request(sems->log_mutex, client_ip, req.method, req.path, 200, file_size);
        free(file_data);
    } else {
        const char msg[] = "404 Not Found\n";
        send_http_response(client_fd, 404, "Not Found", "text/plain", msg, strlen(msg));
        stats_record_response(shared, sems, 404, strlen(msg));
        char client_ip[64] = {0};
        get_client_ip(client_fd, client_ip, sizeof(client_ip));
        log_request(sems->log_mutex, client_ip, req.method, req.path, 404, strlen(msg));
    }

    stats_decrement_active(shared, sems);
}




void run_worker_process(shared_data_t* shared,
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

    // get connection fds from the shared circular buffer and work on it on the local pool
    while (1) {
        int client_fd = dequeue_connection(shared, sems);
        thread_addFd(pool, client_fd); 
    }

   //cleanup
    destroy_thread_pool(pool);
}
