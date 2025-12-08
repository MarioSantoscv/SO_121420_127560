#include "http.h"
#include <string.h>
#include <stdio.h>
#include <unistd.h>

// Simple HTTP request parser: extracts method, path, version from first line
int parse_http_request(const char* buffer, http_request_t* req) {
    char* line_end = strstr(buffer, "\r\n");
    if (!line_end) return -1;
    char first_line[1024];
    size_t len = line_end - buffer;
    if (len >= sizeof(first_line)) return -1;
    strncpy(first_line, buffer, len);
    first_line[len] = '\0';
    if (sscanf(first_line, "%15s %511s %15s", req->method, req->path, req->version) != 3) {
        return -1;
    }
    return 0;
}

// Build HTTP response and send
void send_http_response(int fd, int status, const char* status_msg,
                       const char* content_type, const char* body, size_t body_len) {
    char header[2048];
    int header_len = snprintf(header, sizeof(header),
        "HTTP/1.1 %d %s\r\n"
        "Content-Type: %s\r\n"
        "Content-Length: %zu\r\n"
        "Server: ConcurrentHTTP/1.0\r\n"
        "Connection: close\r\n"
        "\r\n",
        status, status_msg, content_type, body_len);
    send(fd, header, header_len, 0);
    if (body && body_len > 0) {
        send(fd, body, body_len, 0);
    }
}