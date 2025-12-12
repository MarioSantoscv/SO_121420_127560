
#ifndef CACHE_H
#define CACHE_H

#include <pthread.h>
#include <stddef.h>


// Max size of files to cache default: 10MB
#define MAX_CACHE_FILE_SIZE (10*1024*1024) 

typedef struct cache_entry {
    char* path;                 // name of file
    unsigned char* data;        // file contents
    size_t size;                // size of data
    struct cache_entry* prev;
    struct cache_entry* next;
} cache_entry_t;

typedef struct file_cache {
    cache_entry_t* head;        // most recent
    cache_entry_t* tail;        // least recent
    size_t total_size;          // total bytes in cache
    size_t max_size;            // maximum bytes 
    pthread_rwlock_t rwlock;    // reader-writer lock for cache (so that it can be thread-safe so more efficient)
} file_cache_t;

//create the cache
file_cache_t* cache_create(size_t max_size);

// Destroy cache
void cache_destroy(file_cache_t* cache);

// Main cache get — returns malloc'd data or NULL
unsigned char* cache_get(file_cache_t* cache, const char* path, size_t* out_size);

// Insert file into cache
void cache_put(file_cache_t* cache, const char* path, const unsigned char* data, size_t size);

#endif