// thread_pool.h
#ifndef THREAD_POOL_H
#define THREAD_POOL_H

#include <pthread.h>


// Simple work item structure (fd to handle + next pointer)
typedef struct work_item {
    int client_fd;                 
    struct work_item* next;        
} work_item_t;


typedef struct {
    pthread_t* threads;            
    int num_threads;               
    pthread_mutex_t mutex;         // Mutex to protect the work queue
    pthread_cond_t cond;           // Condition variable for signaling work
    int shutdown;                  

    // Work queue
    work_item_t* head;             // Start 
    work_item_t* tail;             // End
} thread_pool_t;


thread_pool_t* create_thread_pool(int num_threads);


void destroy_thread_pool(thread_pool_t* pool);


void thread_addFd(thread_pool_t* pool, int client_fd);

#endif