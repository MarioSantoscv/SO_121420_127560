#include "thread_pool.h"
#include "worker.h"
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>

// Simple work item structure (from your thread_pool.h)
typedef struct work_item {
    int client_fd;
    struct work_item* next;
} work_item_t;




void* worker_thread(void* arg) {
    thread_pool_t* pool = (thread_pool_t*)arg;

    while (1) {
        pthread_mutex_lock(&pool->mutex);
        //entering critical region
        
        // Wait while queue empty and not shutting down
        while (!pool->shutdown && pool->head == NULL) {
            pthread_cond_wait(&pool->cond, &pool->mutex);
        }

        // If shutdown requested and queue empty: exit
        if (pool->shutdown && pool->head == NULL) {
            printf("[THREAD_POOL] thread %lu shutting down\n",
                   (unsigned long)pthread_self()); //print for logging
            pthread_mutex_unlock(&pool->mutex);
            break;
        }

        //pop a work item from the queue
        work_item_t* item = pool->head;
        if (item) {
            pool->head = item->next; //update  head pointer to next item
            if (pool->head == NULL) { 
                pool->tail = NULL; 
            }
        }

        pthread_mutex_unlock(&pool->mutex);
        //exiting critical region

        if (item) {
            int client_fd = item->client_fd;
            printf("[THREAD_POOL] thread %lu handling client_fd=%d\n",
                   (unsigned long)pthread_self(), client_fd);
            free(item);

            // Call handler from worker.c
            extern void handle_client(int client_fd);
            handle_client(client_fd);
            close(client_fd);
        }
    }
    return NULL;
}



thread_pool_t* create_thread_pool(int num_threads) {
    thread_pool_t* pool = malloc(sizeof(thread_pool_t));
    if (!pool) {
        perror("Couldnt malloc thread_pool");
        return NULL;
    }
    pool->threads = malloc(sizeof(pthread_t) * num_threads);
    if (!pool->threads) {
        perror("Couldnt malloc threads");
        free(pool);
        return NULL;
    }
    pool->num_threads = num_threads;
    pool->shutdown = 0;
    //making sure queue is empty at start
    pool->head = NULL;
    pool->tail = NULL;

    pthread_mutex_init(&pool->mutex, NULL); // Mutex to protect the work queue
    pthread_cond_init(&pool->cond, NULL); // Condition variable for signaling work

    for (int i = 0; i < num_threads; i++) {
        if (pthread_create(&pool->threads[i], NULL, worker_thread, pool) == 0) {
            printf("[THREAD_POOL] thread %d created (pthread id: %lu)\n",
                   i, (unsigned long)pool->threads[i]);
        }
    }

    return pool;
}


void thread_addFd(thread_pool_t* pool, int client_fd) {
    //debugging 
    if (!pool) {
        fprintf(stderr, "[THREAD_POOL] Error: pool is NULL\n");
        close(client_fd);
        return;
    }

    work_item_t* item = malloc(sizeof(work_item_t));
    if (!item) {
        perror("Couldnt malloc work_item");
        close(client_fd);
        return;
    }
    item->client_fd = client_fd;
    item->next = NULL;

    pthread_mutex_lock(&pool->mutex);

    //entering critical region

    if (pool->tail == NULL) {
        // Queue was empty
        //so now both head and tail point to the new item because its only one
        pool->head = pool->tail = item;
    } else { //if not empty
        // Append to the end and update tail pointer(check if correct)
        pool->tail->next = item;
        pool->tail = item;
    }
    printf("[THREAD_POOL] Enqueued work item: client_fd=%d\n", client_fd);
    pthread_cond_signal(&pool->cond); // Wake one sleeping worker
    pthread_mutex_unlock(&pool->mutex); //exiting critical region
}

// ---------------------------------------------------------
// Destroy thread pool (shutdown + join + cleanup)
// ---------------------------------------------------------
void destroy_thread_pool(thread_pool_t* pool) {
    if (!pool){
        fprintf(stderr, "[THREAD_POOL] Error: pool is NULL\n");
        return;
    } 

    printf("[THREAD_POOL] Destroying pool: shutdown and joining threads...\n");

    pthread_mutex_lock(&pool->mutex); //entered critical region
    pool->shutdown = 1;
    pthread_cond_broadcast(&pool->cond); // Wake all threads
    pthread_mutex_unlock(&pool->mutex); //exiting critical region

    for (int i = 0; i < pool->num_threads; i++) {
        pthread_join(pool->threads[i], NULL);
        printf("[THREAD_POOL] Joined worker thread %d (pthread id: %lu)\n",
               i, (unsigned long)pool->threads[i]);
    }

    // Free work that is in q but not handled yet
    work_item_t* cur = pool->head;
    while (cur) {
        work_item_t* next = cur->next;
        close(cur->client_fd); // wasn't handled
        free(cur);
        cur = next;
    }

    pthread_mutex_destroy(&pool->mutex);
    pthread_cond_destroy(&pool->cond);
    free(pool->threads);
    free(pool); //for memory leaks free all memory alocated
    printf("[THREAD_POOL] Thread pool destroyed.\n");
}