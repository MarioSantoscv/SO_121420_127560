// log.c
#include "logger.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <semaphore.h>
#include <time.h>
#include <unistd.h>
#include <sys/stat.h>

#define LOG_FILE "access.log"
#define LOG_MAX_SIZE (10*1024) // 10MB

// Helper: rotate log file if exceeds 10MB
static void rotate_log_file(FILE* fp, struct tm* tm_info) {
    if (!fp){
        fprintf(stderr, "Log file pointer is NULL\n");
        return;
    } 
    fseek(fp, 0, SEEK_END); //go to end
    long size = ftell(fp); //get size since we are at the end
    if (size >= LOG_MAX_SIZE) {
        fclose(fp);
        char rotated_name[128];
        strftime(rotated_name, sizeof(rotated_name), //create a new name appending timestamp consult time.h library
                 "access_%Y%m%d%H%M%S.log", tm_info); //decided to do it this way se we did this in the first project too (restore function)
        rename(LOG_FILE, rotated_name);
       
    }
}

// Thread/process safe logging
void log_request(sem_t* log_sem, const char* client_ip, const char* method,
                 const char* path, int status, size_t bytes) {
    time_t now = time(NULL);
    struct tm* tm_info = localtime(&now);
    char timestamp[64];
    strftime(timestamp, sizeof(timestamp), "%d/%b/%Y:%H:%M:%S %z", tm_info);

    sem_wait(log_sem);
    FILE* log = fopen(LOG_FILE, "a");
    if (log) {
        rotate_log_file(log, tm_info); //check if we need to rotate
        log = fopen(LOG_FILE, "a");
        if (log) {
            fprintf(log, "%s - - [%s] \"%s %s HTTP/1.1\" %d %zu\n",
                client_ip, timestamp, method, path, status, bytes);
            fclose(log);
        }
    }
    sem_post(log_sem);
}