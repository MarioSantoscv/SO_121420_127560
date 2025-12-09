// semaphores.h
#ifndef SEMAPHORES_H
#define SEMAPHORES_H

#include <semaphore.h>

typedef struct {
    sem_t* empty_slots; //empty for master to produce
    sem_t* filled_slots; //filled for workers to consume
    sem_t* queue_mutex; //mutual exclusion
    sem_t* stats_mutex; //stats protection
    sem_t* log_mutex;
} semaphores_t;



int init_semaphores(semaphores_t* sems, int queue_size);
void destroy_semaphores(semaphores_t* sems);

#endif
