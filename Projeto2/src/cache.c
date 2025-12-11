#include "cache.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

//remember we are using LRU cache (least recently used) so 
//prev is the newest and next is the oldest!!!

//helper functions
// 1- Remove tail entry from cache
static void cache_remove_tail(file_cache_t* cache) {
    if (!cache->tail){
        fprintf(stderr, "[CACHE] Evicting entry: cache is empty\n");
        return;
    }

    cache_entry_t* old = cache->tail;
    // Remove from list
    if (old->prev)
        old->prev->next = NULL;
    else //was only entry
        cache->head = NULL;

    cache->tail = old->prev;
    // Subtract from total
    cache->total_size -= old->size;
    free(old->path);
    free(old->data);
    free(old);
}

// 2- Move entry to front
static void cache_set_head(file_cache_t* cache, cache_entry_t* entry) {
    if (cache->head == entry) {
        fprintf(stderr, "[CACHE] Promoting entry: already at head\n");
        return;
    }
    // Remove from current position
    if (entry->prev) entry->prev->next = entry->next;  
    if (entry->next) entry->next->prev = entry->prev;
    if (cache->tail == entry && entry->prev)
        cache->tail = entry->prev;
    // Insert at front
    entry->next = cache->head;
    if (cache->head) cache->head->prev = entry;
    entry->prev = NULL;
    cache->head = entry;
    if (!cache->tail) cache->tail = entry;
}

// Create cache
file_cache_t* cache_create(size_t max_size) {
    file_cache_t* cache = calloc(1, sizeof(file_cache_t));
    if (!cache){
        perror("Couldnt malloc cache");
        return NULL;
    }
    cache->max_size = max_size;
    pthread_rwlock_init(&cache->rwlock, NULL); // Initialize rwlock thread safeee
    return cache;
}

// Destroy cache
void cache_destroy(file_cache_t* cache) {
    cache_entry_t* cur = cache->head;
    while (cur) { //looping thru all entries and freeing them
        cache_entry_t* next = cur->next;
        free(cur->data);
        free(cur->path);
        free(cur);
        cur = next;
    }
    pthread_rwlock_destroy(&cache->rwlock);
    free(cache);
}

// Main cache get — returns malloc'd data or NULL
unsigned char* cache_get(file_cache_t* cache, const char* path, size_t* out_size) {
    unsigned char* result = NULL;
    pthread_rwlock_rdlock(&cache->rwlock); //read lock so many threads can do the search at the same time
    //entering critical region

    cache_entry_t* cur = cache->head;
    while (cur) {
        if (strcmp(cur->path, path) == 0) { //found cache entry
            // Found entry: copy data
            result = malloc(cur->size);
            if (result) {
                memcpy(result, cur->data, cur->size);
                if (out_size) *out_size = cur->size;
            }
            break;
        }
        cur = cur->next;
    }
    pthread_rwlock_unlock(&cache->rwlock);

    // If found, put it at front 
    if (result) {
        pthread_rwlock_wrlock(&cache->rwlock); //write lock because we are modifying and only one thread at a time should do this
        //entering critical region
        cur = cache->head;
        while (cur) {
            if (strcmp(cur->path, path) == 0) {
                cache_set_head(cache, cur);
                break;
            }
            cur = cur->next;
        }
        pthread_rwlock_unlock(&cache->rwlock);
    }
    return result;
}

// Insert new file into cache
void cache_put(file_cache_t* cache, const char* path, const unsigned char* data, size_t size) {
    if (size > MAX_CACHE_FILE_SIZE) return; 
    pthread_rwlock_wrlock(&cache->rwlock);

    // if exists, replace
    cache_entry_t* cur = cache->head;
    while (cur) {
        if (strcmp(cur->path, path) == 0) {
            // Replace data
            free(cur->data);
            cur->data = malloc(size);
            if (cur->data) {
                memcpy(cur->data, data, size);
                cur->size = size;
                cache_set_head(cache, cur);
            }
            pthread_rwlock_unlock(&cache->rwlock);
            return;
        }
        cur = cur->next;
    }

    // remove entries if needed
    while (cache->total_size + size > cache->max_size) {
        cache_remove_tail(cache);
    }

    // if doesnt exist, create new
    cache_entry_t* entry = calloc(1, sizeof(cache_entry_t));
    entry->path = strdup(path);//duplicate the string
    entry->data = malloc(size);
    if (!entry->path || !entry->data) {
        free(entry->path);
        free(entry->data);
        free(entry);
        pthread_rwlock_unlock(&cache->rwlock);
        return;
    }
    memcpy(entry->data, data, size);
    entry->size = size;

    // Insert at front since we are using lru type of cache
    entry->next = cache->head;
    if (cache->head) cache->head->prev = entry;
    cache->head = entry;
    if (!cache->tail) cache->tail = entry;
    cache->total_size += size;

    pthread_rwlock_unlock(&cache->rwlock);
}