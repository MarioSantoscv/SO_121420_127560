#define _POSIX_C_SOURCE 200809L
#include "master.h"
#include "thread_pool.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <stdlib.h>

/* Helper: write a minimal 503 response and close */
static void respond_503_and_close(int client_fd) {
    const char resp[] =
        "HTTP/1.1 503 Service Unavailable\r\n"
        "Connection: close\r\n"
        "Content-Length: 19\r\n"
        "Content-Type: text/plain\r\n"
        "\r\n"
        "503 Service Unavailable";
    ssize_t w = write(client_fd, resp, sizeof(resp)-1);
    (void)w; /* ignore write errors for this minimal server */
    close(client_fd);
}

int master_run(const char *port, connection_queue_t *q, int max_clients) {
    struct addrinfo hints, *res = NULL, *rp;
    int listen_fd = -1;
    int yes = 1;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;    /* IPv4 or IPv6 */
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_PASSIVE;    /* for bind */

    if (getaddrinfo(NULL, port, &hints, &res) != 0) {
        perror("getaddrinfo");
        return -1;
    }
    for (rp = res; rp != NULL; rp = rp->ai_next) {
        listen_fd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
        if (listen_fd == -1) continue;
        setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
        if (bind(listen_fd, rp->ai_addr, rp->ai_addrlen) == 0) break;
        close(listen_fd);
        listen_fd = -1;
    }
    if (listen_fd == -1) {
        fprintf(stderr, "Failed to bind\n");
        freeaddrinfo(res);
        return -1;
    }
    freeaddrinfo(res);
    if (listen(listen_fd, max_clients) == -1) {
        perror("listen");
        close(listen_fd);
        return -1;
    }
    printf("Master listening on port %s\n", port);

    for (;;) {
        struct sockaddr_storage cli_addr;
        socklen_t cli_len = sizeof(cli_addr);
        int client_fd = accept(listen_fd, (struct sockaddr *)&cli_addr, &cli_len);
        if (client_fd == -1) {
            if (errno == EINTR) continue;
            perror("accept");
            break;
        }
        /* Try to enqueue. If full, respond 503 and close. */
        if (queue_enqueue(q, client_fd) == -1) {
            respond_503_and_close(client_fd);
            continue;
        }
        /* else connection accepted and queued for workers */
    }
    close(listen_fd);
    return 0;
}