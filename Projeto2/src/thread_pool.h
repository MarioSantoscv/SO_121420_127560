// thread_pool.h
#ifndef THREAD_POOL_H
#define THREAD_POOL_H

#include <pthread.h>

// Function type used to handle each client connection
typedef void (*task_handler_t)(int client_fd, void* arg);

typedef struct work_item {
    int client_fd;
    struct work_item* next;
} work_item_t;

typedef struct {
    pthread_t* threads;
    int num_threads;

    pthread_mutex_t mutex;
    pthread_cond_t  cond;
    int shutdown;

    // Local request queue inside the worker process
    work_item_t* head;
    work_item_t* tail;

    // Function that processes a client connection
    task_handler_t handler;
    void* handler_arg;
} thread_pool_t;

// Create pool with fixed number of threads and a task handler.
thread_pool_t* create_thread_pool(int num_threads,
                                  task_handler_t handler,
                                  void* handler_arg);

// Submit a new client_fd to the pool’s internal queue.
void thread_pool_add_work(thread_pool_t* pool, int client_fd);

// Ask threads to stop and join them (cleanup).
void destroy_thread_pool(thread_pool_t* pool);

#endif
