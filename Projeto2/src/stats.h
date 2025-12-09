#ifndef STATS_H
#define STATS_H

#include "shared_mem.h"
#include "semaphores.h"
#include <stddef.h> // for size_t


void stats_increment_active(shared_data_t* shared, semaphores_t* sems);


void stats_decrement_active(shared_data_t* shared, semaphores_t* sems);


void stats_record_response(shared_data_t* shared, semaphores_t* sems, int status, long bytes);

#endif