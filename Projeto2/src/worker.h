// worker.h
#ifndef WORKER_H
#define WORKER_H

#include "shared_mem.h"
#include "semaphores.h"
#include "config.h"

// Prefork model: workers accept on the shared listening socket inherited from parent.
void run_worker_process(int listen_fd,
                        shared_data_t* shared,
                        semaphores_t* sems,
                        const server_config_t* config);

#endif
