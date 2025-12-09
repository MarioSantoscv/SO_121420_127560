#include "config.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int load_server_config(const char* filename, server_config_t* config) {
    FILE* file = fopen(filename, "r");
    if (!file) return -1;

    char line[256];
    while (fgets(line, sizeof(line), file)) {
        // Skip comments and empty lines
        if (line[0] == '#' || line[0] == '\n') continue;
        char key[64], value[192];
        if (sscanf(line, "%63[^=]=%191[^\n]", key, value) == 2) {
            if (strcmp(key, "PORT") == 0)
                config->port = atoi(value);
            else if (strcmp(key, "DOCUMENT_ROOT") == 0)
                strncpy(config->document_root, value, sizeof(config->document_root)-1);
            else if (strcmp(key, "NUM_WORKERS") == 0)
                config->num_workers = atoi(value);
            else if (strcmp(key, "THREADS_PER_WORKER") == 0)
                config->threads_per_worker = atoi(value);
            else if (strcmp(key, "MAX_QUEUE_SIZE") == 0)
                config->max_queue_size = atoi(value);
            else if (strcmp(key, "LOG_FILE") == 0)
                strncpy(config->log_file, value, sizeof(config->log_file)-1);
            else if (strcmp(key, "CACHE_SIZE_MB") == 0)
                config->cache_size_mb = atoi(value);
            else if (strcmp(key, "TIMEOUT_SECONDS") == 0)
                config->timeout_seconds = atoi(value);
        }
    }
    fclose(file);
    return 0;
}