typedef struct cache_entry {
    char* path;                 // absolute or relative pathname
    unsigned char* data;        // file contents
    size_t size;                // size of data
    struct cache_entry* prev;
    struct cache_entry* next;
} cache_entry_t;

typedef struct file_cache {
    cache_entry_t* head;        // most recently used
    cache_entry_t* tail;        // least recently used
    size_t total_size;          // total bytes cached
    size_t max_size;            // maximum bytes to allow
    pthread_rwlock_t rwlock;    // reader-writer lock for cache
} file_cache_t;

// Create a cache (max_size in bytes)
file_cache_t* cache_create(size_t max_size);

// Destroy a cache and free memory
void cache_destroy(file_cache_t* cache);

// Check cache for file data. Returns malloc'ed buffer and set out_size, or NULL if not found.
unsigned char* cache_get(file_cache_t* cache, const char* path, size_t* out_size);

// Insert new file into cache (data is copied!)
void cache_put(file_cache_t* cache, const char* path, const unsigned char* data, size_t size);

#endif