#include "stats.h"
#include "semaphores.h"
#include "shared_mem.h"



void stats_increment_active(shared_data_t* shared, semaphores_t* sems) {
    sem_wait(sems->stats_mutex);
    shared->stats.active_connections++;
    sem_post(sems->stats_mutex);
}


void stats_decrement_active(shared_data_t* shared, semaphores_t* sems) {
    sem_wait(sems->stats_mutex);
    shared->stats.active_connections--;
    sem_post(sems->stats_mutex);
}


void stats_record_response(shared_data_t* shared, semaphores_t* sems, int status, long bytes) {
    sem_wait(sems->stats_mutex);
    shared->stats.total_requests++;
    shared->stats.bytes_transferred += bytes;
    if (status == 200)
        shared->stats.status_200++;
    else if (status == 404)
        shared->stats.status_404++;
    else if (status == 403)
        shared->stats.status_403++;
    else if (status == 400)
        shared->stats.status_400++;
    else if (status == 405)
        shared->stats.status_405++;
    else if (status == 500)
        shared->stats.status_500++;
    //if needed to add in the future other codes just add here(ask teacher about this) consult semrush blog to see more about them
    sem_post(sems->stats_mutex);
}