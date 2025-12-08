// master.c
#include "master.h"
#include "shared_mem.h"
#include "semaphores.h"
#include "config.h"
#include "stats.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <signal.h>
#include <errno.h>
#include <string.h>

volatile sig_atomic_t keep_running = 1;

void signal_handler(int signum) {
    (void)signum;
    keep_running = 0;
}

int create_server_socket(int port) {
    int sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0) return -1;

    int opt = 1;
    setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr;
    addr.sin_family      = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port        = htons(port);

    if (bind(sockfd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(sockfd);
        return -1;
    }

    if (listen(sockfd, 128) < 0) {
        close(sockfd);
        return -1;
    }

    return sockfd;
}

static void send_503(int client_fd) {
    const char resp[] =
        "HTTP/1.1 503 Service Unavailable\r\n"
        "Content-Length: 19\r\n"
        "Content-Type: text/plain\r\n"
        "Connection: close\r\n"
        "\r\n"
        "Service Unavailable";
    send(client_fd, resp, sizeof(resp) - 1, 0);
    close(client_fd);
}



// Producer is going to push client_fd into shared circular buffer
static void enqueue_connection(shared_data_t* data,
                               semaphores_t* sems,
                               int client_fd) {
    // Try to decrement empty_slots without error
    if (sem_trywait(sems->empty_slots) == -1) {
        if (errno == EAGAIN) {
            // Queue is full -> respond 503 and return
            send_503(client_fd);
            return;
        } else {
            perror("sem_trywait(empty_slots)");
            close(client_fd);
            return;
        }
    }

    sem_wait(sems->queue_mutex); //waiting for the semaphore to let the client enter the critical region (waiting for the key to get in the room)

    //Entered critical region
    //Put connection into the buffer (code snipet from teacher template)
    data->queue.sockets[data->queue.rear] = client_fd;
    data->queue.rear  = (data->queue.rear + 1) % MAX_QUEUE_SIZE; //wrap around (moving the rear pointer)
    data->queue.count++;

    sem_post(sems->queue_mutex);
    sem_post(sems->filled_slots);
}


static void print_stats(const shared_data_t* shared, const semaphores_t* sems) {
    sem_wait(sems->stats_mutex);
    printf("\n------ Server Stats ------\n");
    printf("Total requests:      %ld\n", shared->stats.total_requests);
    printf("Bytes transferred:   %ld\n", shared->stats.bytes_transferred);
    printf("HTTP 200 responses:  %ld\n", shared->stats.status_200);
    printf("HTTP 404 responses:  %ld\n", shared->stats.status_404);
    printf("HTTP 500 responses:  %ld\n", shared->stats.status_500);
    printf("Active connections:  %d\n",  shared->stats.active_connections);
    printf("--------------------------\n");
    sem_post(sems->stats_mutex);
}

static void stats_loop(const shared_data_t* shared, const semaphores_t* sems) {
    while (keep_running) {
        sleep(30); // print every 30 seconds
        print_stats(shared, sems);
    }
}

void run_master(int listen_fd,
                shared_data_t* shared,
                semaphores_t* sems,
                const server_config_t* config) {
    (void)config; // not used yet in Feature 1

    struct sockaddr_in client_addr; //get the client address information
    socklen_t client_len = sizeof(client_addr);

    //For the stats printing every 30seconds we create a child process to run in the background and handle the printing(could also use threads)
    //include in report
    pid_t stats_pid = fork();
    if (stats_pid == 0) {
        stats_loop(shared, sems);
        exit(0);
    }
    while (keep_running) {
        int client_fd = accept(listen_fd, //create the connection 
                               (struct sockaddr*)&client_addr,
                               &client_len);
        if (client_fd < 0) {
            if (errno == EINTR) continue; // interrupted by signal
            perror("accept");
            break;
        }

        // Put the connection into the shared queue
        enqueue_connection(shared, sems, client_fd);
    }

    close(listen_fd);
    kill(stats_pid, SIGTERM); //terminate the stats process
}
