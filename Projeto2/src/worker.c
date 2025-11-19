// worker.c
#include "worker.h"
#include "shared_mem.h"
#include "semaphores.h"
#include "config.h"
#include "thread_pool.h"

#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <sys/socket.h>

// CONSUMER: pops a client_fd from the shared circular buffer
static int dequeue_connection(shared_data_t* data, semaphores_t* sems) {
    int client_fd;

    // Wait until there is at least one filled slot
    sem_wait(sems->filled_slots);
    sem_wait(sems->queue_mutex);

    client_fd = data->queue.sockets[data->queue.front];
    data->queue.front = (data->queue.front + 1) % MAX_QUEUE_SIZE;
    data->queue.count--;

    sem_post(sems->queue_mutex);
    sem_post(sems->empty_slots);

    return client_fd;
}

/*
 * Per-connection handler.
 * This is what the thread pool calls for each client_fd.
 * IMPORTANT: we only send the response here; the socket is
 * closed in thread_pool.c after handle_client() returns.
 */
void handle_client(int client_fd) {
    const char msg[] =
        "HTTP/1.1 200 OK\r\n"
        "Content-Length: 13\r\n"
        "Content-Type: text/plain\r\n"
        "Connection: close\r\n"
        "\r\n"
        "Hello, world!";

    // ignore send errors for now – focus on queue + pool
    send(client_fd, msg, sizeof(msg) - 1, 0);
}

// Main function for each worker *process*
void run_worker_process(shared_data_t* shared,
                        semaphores_t* sems,
                        const server_config_t* config) {
    // 1. Create the thread pool (fixed number of threads)
    thread_pool_t* pool = create_thread_pool(config->threads_per_worker);
    if (!pool) {
        perror("create_thread_pool");
        _exit(1);
    }

    // 2. Dispatcher loop: move from global shared queue -> local thread pool
    while (1) {
        int client_fd = dequeue_connection(shared, sems);
        if (client_fd < 0) {
            // Shouldn't normally happen, but just in case
            continue;
        }

        thread_pool_add_work(pool, client_fd);
    }

    // 3. In a proper shutdown, you'll break the loop above and then:
    destroy_thread_pool(pool);
}
