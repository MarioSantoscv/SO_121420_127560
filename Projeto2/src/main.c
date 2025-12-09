// main.c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <sys/wait.h>

#include "shared_mem.h"
#include "semaphores.h"
#include "master.h"
#include "worker.h"
#include "config.h"
#include "logger.h"
#include "stats.h"
#include "cache.h"
#include "http.h"
#include "thread_pool.h"

int main() {
    server_config_t config;

    if (load_server_config("server.conf", &config) != 0) {
        perror("load_server_config");
        exit(1);
    }

    // 1. Create shared memory
    shared_data_t* shared = create_shared_memory();
    if (!shared) {
        perror("create_shared_memory");
        exit(1);
    }

    // 2. Create semaphores
    semaphores_t sems;
    if (init_semaphores(&sems, config.max_queue_size) != 0) {
        perror("init_semaphores");
        exit(1);
    }

    // 3. Create listening socket
    int listen_fd = create_server_socket(config.port);
    if (listen_fd < 0) {
        perror("create_server_socket");
        exit(1);
    }

    // 4. Fork workers
    for (int i = 0; i < config.num_workers; i++) {
        pid_t pid = fork();
        if (pid == 0) {
            // Worker process
            run_worker_process(shared, &sems, &config);
            exit(0);
        }
    }

    // 5. Master loop
    run_master(listen_fd, shared, &sems, &config);

    // 6. Cleanup (master only)
    destroy_semaphores(&sems);
    destroy_shared_memory(shared);

    return 0;
}
