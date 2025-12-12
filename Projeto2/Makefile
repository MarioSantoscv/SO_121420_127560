# Simple Makefile for HTTP Server Project

# Compiler & flags
CC = gcc
CFLAGS = -Wall -Wextra -pedantic -g
LDFLAGS = -lpthread

VPATH = src

# Source files (add/remove as needed)
SRCS = main.c logger.c cache.c stats.c http.c thread_pool.c shared_mem.c semaphores.c config.c master.c worker.c
OBJS = $(SRCS:.c=.o)

# Executable name
TARGET = myserver

# Default target
all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

# Pattern rule: compile .c to .o
%.o: %.c
	$(CC) $(CFLAGS) -c $<

# Variaveis para os testes
TEST_SRCS = tests/test_concurrent.c
TEST_OBJS = $(TEST_SRCS:.c=.o)
TEST_TARGET = tests/test_concurrent

# Regra para compilar o binário de teste
$(TEST_TARGET): $(TEST_OBJS)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

# Regra para compilar ficheiros C que estejam na diretoria tests/
tests/%.o: tests/%.c
	$(CC) $(CFLAGS) -c $< -o $@

# Target para executar todos os testes (requer o servidor compilado)
test: $(TARGET) $(TEST_TARGET)
	@echo "\n--- 🏃 A EXECUTAR TESTES DE FUNCIONALIDADE E CONCORRÊNCIA ---"
	@echo "Lançamento do test_load.sh (Funcional, Carga, Shutdown)..."
	@bash tests/test_load.sh
	@echo "\nLançamento do test_concurrent (Stress na Fila IPC)..."
	@# Executa 5000 clientes, 200 em simultâneo na porta 8080.
	@./tests/test_concurrent 8080 5000 200

# Targets individuais
test_load: $(TARGET)
	@bash tests/test_load.sh

test_concurrent_run: $(TEST_TARGET)
	@./tests/test_concurrent 8080 5000 200

# Targets para Valgrind
valgrind: $(TARGET)
	@echo "\n--- 🧪 A EXECUTAR VALGRIND (Verifique se o servidor está a correr com Valgrind) ---"
	valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes ./$(TARGET)

helgrind: $(TARGET)
	@echo "\n--- 🧪 A EXECUTAR HELGRIND (Condições de Corrida) ---"
	valgrind --tool=helgrind ./$(TARGET)
 

# Clean up build artifacts (inclui os objetos e binários dos testes)
clean:
	rm -f $(OBJS) $(TARGET) $(TEST_OBJS) $(TEST_TARGET)
	@echo "Ficheiros de build e binários de teste removidos."

ipc_clean:
	@echo "Removendo recursos IPC persistentes (semáforos e memória partilhada)..."
	@# Assumindo que os seus semáforos e shm têm nomes padrão
	@# Deve adaptar esta lista aos nomes exatos que usou no seu código
	@sudo rm -f /dev/shm/sem.sem_empty_slots
	@sudo rm -f /dev/shm/sem.sem_filled_slots
	@sudo rm -f /dev/shm/sem.sem_queue_mutex
	@sudo rm -f /dev/shm/shm_queue

# Atualizar .PHONY para incluir os novos targets
.PHONY: all clean test test_load test_concurrent_run valgrind helgrind