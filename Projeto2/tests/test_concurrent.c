#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <pthread.h>
#include <time.h>

#define SERVER_IP "127.0.0.1"
#define REQUEST "GET /index.html HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n"
#define MAX_BUFFER 2048

//Variáveis globais para contagem
volatile int success_count = 0;
volatile int failure_count = 0;
pthread_mutex_t count_mutex; // Mutex para proteger as contagens globais

//Estrutura de argumentos para a thread cliente
typedef struct {
    int port;
} client_args_t;

//Fução executada por cada thread (cliente)
void* run_client(void* arg) {
    client_args_t* args = (client_args_t*)arg;
    int client_fd;
    struct sockaddr_in server_addr;
    char buffer[MAX_BUFFER];
    ssize_t bytes_received;
    int client_success = 0;

    // create Socket
    if ((client_fd = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
        goto end;
    }

    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(args->port);
    inet_pton(AF_INET, SERVER_IP, &server_addr.sin_addr);

    //connect
    if (connect(client_fd, (struct sockaddr*)&server_addr, sizeof(server_addr)) < 0) {
        goto end;
    }

    //send requisitation
    if (send(client_fd, REQUEST, strlen(REQUEST), 0) < 0) {
        goto end;
    }

    //Recieve
    bytes_received = recv(client_fd, buffer, MAX_BUFFER - 1, 0);
    if (bytes_received > 0) {
        buffer[bytes_received] = '\0';
        // Sucesso if 200 OK ou 503
        if (strstr(buffer, "200 OK") || strstr(buffer, "503 Service Unavailable")) {
            client_success = 1;
        }
    }
    
end:
    if (client_fd > 0) close(client_fd);
    
    // Atualiza contagens globais de forma segura
    pthread_mutex_lock(&count_mutex);
    if (client_success) {
        success_count++;
    } else {
        failure_count++;
    }
    pthread_mutex_unlock(&count_mutex);

    return NULL;
}

int main(int argc, char* argv[]) {
    if (argc != 4) {
        fprintf(stderr, "Uso: %s <porta> <num_clientes> <num_threads_simultaneas>\n", argv[0]);
        return 1;
    }

    int port = atoi(argv[1]);
    int num_clients = atoi(argv[2]);
    int concurrency = atoi(argv[3]);
    
    if (num_clients <= 0 || concurrency <= 0 || concurrency > num_clients) {
        fprintf(stderr, "Valores de clientes e concorrência inválidos.\n");
        return 1;
    }

    pthread_mutex_init(&count_mutex, NULL);
    pthread_t *threads = (pthread_t*)malloc(sizeof(pthread_t) * num_clients);
    client_args_t args = { .port = port };
    
    printf("--- Teste de Concorrência de Sockets ---\n");
    printf("Porta: %d, Total Clientes: %d, Concorrência Máx: %d\n", port, num_clients, concurrency);

    time_t start_time = time(NULL);
    int active_threads = 0;
    
    // Lógica para limitar a concorrência, i.e pool de threads no cliente
    for (int i = 0; i < num_clients; i++) {
        if (active_threads >= concurrency) {
            // Espera por uma thread mais antiga para liberar slot
            pthread_join(threads[i - concurrency], NULL);
            active_threads--;
        }
        
        if (pthread_create(&threads[i], NULL, run_client, &args) != 0) {
            perror("pthread_create");
            pthread_mutex_lock(&count_mutex);
            failure_count++;
            pthread_mutex_unlock(&count_mutex);
        } else {
            active_threads++;
        }
    }

    // Wait pelas threads restantes
    for (int i = num_clients - concurrency; i < num_clients; i++) {
        if (i >= 0) {
            pthread_join(threads[i], NULL);
        }
    }
    
    time_t end_time = time(NULL);

    printf("\n--- Resultados ---\n");
    printf("Total de Requisições Enviadas: %d\n", num_clients);
    printf("Conexões com Sucesso (200/503): %d\n", success_count);
    printf("Conexões com Falha/Erro (Timeout, etc.): %d\n", failure_count);
    printf("Tempo Total (s): %ld\n", end_time - start_time);

    free(threads);
    pthread_mutex_destroy(&count_mutex);

    // Critério de Sucesso do Teste: Todas as requisições devem ser contabilizadas
    if (success_count + failure_count == num_clients) {
        return 0;
    }
    return 1;

    // Uso de AI chatgpt para acertos de erros.
}