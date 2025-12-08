// worker.c
#include "worker.h"
#include "shared_mem.h"
#include "semaphores.h"
#include "config.h"
#include "thread_pool.h"
#include "stats.h"

#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <sys/socket.h>

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


//ignore for now 
/*
 * Per-connection handler.
 * This is what the thread pool calls for each client_fd.
 * IMPORTANT: we only send the response here; the socket is
 * closed in thread_pool.c after handle_client() returns.
 */
void handle_client(int client_fd, shared_data_t* shared, semaphores_t* sems) {

    stats_increment_active(shared, sems); // Increment active connections (replace NULLs with actual pointers if needed)
    const char msg[] =
        "HTTP/1.1 200 OK\r\n"
        "Content-Length: 13\r\n"
        "Content-Type: text/plain\r\n"
        "Connection: close\r\n"
        "\r\n"
        "Hello, world!";

    ssize_t bytes_sent = send(client_fd, msg, sizeof(msg) - 1, 0);
        if (bytes_sent == -1) {
            perror("send");
        }
    stats_record_response(shared, sems, 200, bytes_sent); // Record response stats

    stats_decrement_active(shared, sems); // Decrement active connections
}

shared_data_t* g_shared;
semaphores_t* g_sems;

void run_worker_process(shared_data_t* shared,
                        semaphores_t* sems,
                        const server_config_t* config) {
    // Expose shared memory and semaphores as globals for handlers
    g_shared = shared;
    g_sems = sems;

    //Create the thread pool get the number from config
    thread_pool_t* pool = create_thread_pool(config->threads_per_worker);
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
