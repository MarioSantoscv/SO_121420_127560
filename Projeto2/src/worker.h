// worker.h
#ifndef WORKER_H
#define WORKER_H

#include "shared_mem.h"
#include "semaphores.h"
#include "config.h"

void run_worker_process(shared_data_t* shared,
                        semaphores_t* sems,
                        const server_config_t* config);

#endif
