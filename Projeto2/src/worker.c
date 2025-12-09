// worker.c
#include "worker.h"
#include "shared_mem.h"
#include "semaphores.h"
#include "config.h"
#include "thread_pool.h"
#include "stats.h"
#include "cache.h"
#include "http.h"


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

//Helper to format the request line for logging
static void get_request(const http_request_t* req, char* line, size_t len) {
    snprintf(line, len, "%s %s %s", req->method, req->path, req->version);
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
    stats_increment_active(shared, sems);

    char buffer[2048] = {0}; //set a 2KB buffer to read the request

    ssize_t rlen = recv(client_fd, buffer, sizeof(buffer)-1, 0);
    //error or connection closed by client
    if (rlen <= 0) {
        stats_decrement_active(shared, sems);
        return;
    }

    http_request_t req;
    //get request (uses teacher function)
    if (parse_http_request(buffer, &req) != 0) {
        const char err_msg[] = "Malformed HTTP request\n";
        send_http_response(client_fd, 400, "Bad Request", "text/plain",
                          err_msg, strlen(err_msg)); //send a 400 bad request if parser returns -1
        stats_record_response(shared, sems, 400, strlen(err_msg)); //increment stats
       
        char client_ip[64] = {0};
        get_client_ip(client_fd, client_ip, sizeof(client_ip)); // log the IP even for bad requests
        log_request(sems->log_mutex, client_ip, "GET", "-", 400, strlen(err_msg));
        
        stats_decrement_active(shared, sems);
        return;
    }

    if (strcmp(req.method, "GET") != 0) {
        const char err_msg[] = "Only GET supported\n";
        send_http_response(client_fd, 405, "Method Not Allowed", "text/plain",
                          err_msg, strlen(err_msg)); //send a 405 method not allowed if not GET
        stats_record_response(shared, sems, 405, strlen(err_msg));
      
        char client_ip[64] = {0};
        get_client_ip(client_fd, client_ip, sizeof(client_ip));
        log_request(sems->log_mutex, client_ip, req.method, req.path, 405, strlen(err_msg));
       
        stats_decrement_active(shared, sems);
        return;
    }

    //Security: to prevend malformed paths (copilot suggestion)
    if (strstr(req.path, "..")) {
        const char err_msg[] = "Forbidden path\n";
        send_http_response(client_fd, 403, "Forbidden", "text/plain",
                          err_msg, strlen(err_msg));
        stats_record_response(shared, sems, 403, strlen(err_msg));
       
        char client_ip[64] = {0};
        get_client_ip(client_fd, client_ip, sizeof(client_ip));
        log_request(sems->log_mutex, client_ip, req.method, req.path, 403, strlen(err_msg));
       
        stats_decrement_active(shared, sems);
        return;
    }

    //get the file path remove first /
    char file_path[600];
    snprintf(file_path, sizeof(file_path), "%s", req.path+1); 

    //get file from the cache
    size_t file_size = 0;
    unsigned char* file_data = cache_get(g_cache, file_path, &file_size);

    if (file_data && file_size > 0) { 
        //application/octet-stream for all types of files
        send_http_response(client_fd, 200, "OK", "application/octet-stream", //file is found so we send a 200 OK
                           (const char*)file_data, file_size);
        stats_record_response(shared, sems, 200, file_size);
        
        char client_ip[64] = {0};
        get_client_ip(client_fd, client_ip, sizeof(client_ip));
        log_request(sems->log_mutex, client_ip, req.method, req.path, 200, file_size);
        
        free(file_data);
    } else {
        const char msg[] = "404 Not Found (file not in cache)\n";
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


    // Create the file cache
    size_t cache_bytes = 10 * 1024 * 1024;//default the 10MB if cant read from config
    if (config->cache_size_mb > 0) cache_bytes = config->cache_size_mb * 1024 * 1024;
    g_cache = cache_create(cache_bytes);
    if (!g_cache) {
        perror("Couldnt create cache");
        exit(EXIT_FAILURE);
    }

    //Default number of threads per worker is 4 if config is invalid
    //Create the thread pool get the number from config
    thread_pool_t* pool = create_thread_pool(4);
    if (config->threads_per_worker > 0) pool = create_thread_pool(config->threads_per_worker);
    
    if (!pool) {
        perror("Couldnt create thread pool");
        return;
    }

    // get connection fds from the shared circular buffer and work on it on the local pool
    while (1) {
        int client_fd = dequeue_connection(shared, sems);
        thread_pool_add_work(pool, client_fd); // changed name for clarity
    }

   //cleanup
    destroy_thread_pool(pool);
}
