// thread_pool.c
#include "thread_pool.h"

#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/socket.h> // for close()

// This will be implemented on the worker side
extern void handle_client(int client_fd);

// ---------------------------------------------------------
// Worker thread main loop
// ---------------------------------------------------------
void* worker_thread(void* arg) {
    thread_pool_t* pool = (thread_pool_t*)arg;

    while (1) {
        pthread_mutex_lock(&pool->mutex);

        // Wait while queue is empty and not shutting down
        while (!pool->shutdown && pool->head == NULL) {
            pthread_cond_wait(&pool->cond, &pool->mutex);
        }

        // If shutdown requested and no pending work: exit
        if (pool->shutdown && pool->head == NULL) {
            pthread_mutex_unlock(&pool->mutex);
            break;
        }

        // Dequeue work item and process
        work_item_t* item = pool->head;
        pool->head = item->next;
        if (pool->head == NULL) {
            pool->tail = NULL;
        }

        pthread_mutex_unlock(&pool->mutex);

        int client_fd = item->client_fd;
        free(item);

        // Process this connection
        handle_client(client_fd);
        close(client_fd);
    }

    return NULL;
}

// ---------------------------------------------------------
// Create thread pool (template + queue init)
// ---------------------------------------------------------
thread_pool_t* create_thread_pool(int num_threads) {
    thread_pool_t* pool = malloc(sizeof(thread_pool_t));
    if (!pool) {
        perror("malloc thread_pool");
        return NULL;
    }

    pool->threads = malloc(sizeof(pthread_t) * num_threads);
    if (!pool->threads) {
        perror("malloc threads");
        free(pool);
        return NULL;
    }

    pool->num_threads = num_threads;
    pool->shutdown    = 0;

    // Initialize local queue
    pool->head = NULL;
    pool->tail = NULL;

    pthread_mutex_init(&pool->mutex, NULL);
    pthread_cond_init(&pool->cond, NULL);

    for (int i = 0; i < num_threads; i++) {
        if (pthread_create(&pool->threads[i], NULL, worker_thread, pool) != 0) {
            perror("pthread_create");
            // (optional) you could handle partial failures more carefully
        }
    }

    return pool;
}

// ---------------------------------------------------------
// Add work to the pool (enqueue client_fd)
// ---------------------------------------------------------
void thread_pool_add_work(thread_pool_t* pool, int client_fd) {
    if (!pool) {
        close(client_fd);
        return;
    }

    work_item_t* item = malloc(sizeof(work_item_t));
    if (!item) {
        perror("malloc work_item");
        close(client_fd);
        return;
    }

    item->client_fd = client_fd;
    item->next      = NULL;

    pthread_mutex_lock(&pool->mutex);

    if (pool->tail == NULL) {
        // queue was empty
        pool->head = pool->tail = item;
    } else {
        pool->tail->next = item;
        pool->tail       = item;
    }

    // Wake one sleeping worker thread
    pthread_cond_signal(&pool->cond);

    pthread_mutex_unlock(&pool->mutex);
}

// ---------------------------------------------------------
// Destroy thread pool (shutdown + join + cleanup)
// ---------------------------------------------------------
void destroy_thread_pool(thread_pool_t* pool) {
    if (!pool) return;

    // 1. Signal shutdown and wake all threads
    pthread_mutex_lock(&pool->mutex);
    pool->shutdown = 1;
    pthread_cond_broadcast(&pool->cond);
    pthread_mutex_unlock(&pool->mutex);

    // 2. Join all threads
    for (int i = 0; i < pool->num_threads; i++) {
        pthread_join(pool->threads[i], NULL);
    }

    // 3. Free any queued but unprocessed work
    work_item_t* cur = pool->head;
    while (cur) {
        work_item_t* next = cur->next;
        close(cur->client_fd); // never handled
        free(cur);
        cur = next;
    }

    // 4. Destroy sync primitives and free memory
    pthread_mutex_destroy(&pool->mutex);
    pthread_cond_destroy(&pool->cond);

    free(pool->threads);
    free(pool);
}
