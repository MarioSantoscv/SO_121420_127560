# Simple Makefile for HTTP Server Project

# Compiler & flags
CC = gcc
CFLAGS = -Wall -Wextra -pedantic -g
LDFLAGS = -lpthread

# Source files (add/remove as needed)
SRCS = main.c  logger.c cache.c stats.c http.c thread_pool.c shared_mem.c semaphores.c config.c master.c worker.c
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

# Clean up build artifacts
clean:
	rm -f $(OBJS) $(TARGET)

.PHONY: all clean