// shared_mem.h
#ifndef SHARED_MEM_H
#define SHARED_MEM_H

#include <stddef.h>
#define MAX_QUEUE_SIZE 100
#define STATUS_CODES_RANGE 600


//strcture defined to hold the server stats
typedef struct {
    long total_requests;
    long bytes_transferred;
    long status_200;
    long status_404;
    long status_500;
    long status_403;
    long status_400;
    long status_405;
    int active_connections;
} server_stats_t;

typedef struct {
    int sockets[MAX_QUEUE_SIZE]; //holds the fd's
    int front; //worker reads here
    int rear; //master writes here
    int count; //number of fd's in queue
} connection_queue_t;

typedef struct {
    connection_queue_t queue;
    server_stats_t stats; //server stats
} shared_data_t;

shared_data_t* create_shared_memory();
void destroy_shared_memory(shared_data_t* data);

#endif