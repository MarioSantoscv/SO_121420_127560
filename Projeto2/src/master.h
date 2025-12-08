#ifndef MASTER_H
#define MASTER_H

#include "shared_mem.h"
#include "semaphores.h"
#include "config.h"

// From master.c:
int create_server_socket(int port);

void run_master(int listen_fd,
                shared_data_t* shared,
                semaphores_t* sems,
                const server_config_t* config);

#endif
