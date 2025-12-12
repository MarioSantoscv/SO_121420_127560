# Multi-Threaded Web Server with IPC and Semaphores Projet - Reference Solution
**Sistems Operativos – TP2**
A production-grade concurrent HTTP/1.1 web server implementing advanced process and thread
synchronization using POSIX semaphores, shared memory, and thread pools.n

## Overview
This is a complete reference solution for the Web Server Management
System IPC project. It demonstrates proper implementation of:
- **POSIX Shared Memory** for inter-process communication
- **POSIX Named Semaphores** for process synchronization
- **Multi-process architecture** (manager + worker processes)
- **Thread pools** (pthread-based) within each worker
- **HTTP/1.1 protocol** (GET requests, static file serving)
- **Producer-consumer pattern** with bounded buffer
- **Signal handling** for graceful shutdown
- **Resource cleanup** (no memory leaks)

This project implements a multi-process, multi-threaded HTTP/1.1 web server that demonstrates:
• Process Management: Master-worker architecture using fork()
• Inter-Process Communication: Shared memory and POSIX semaphores
• Thread Synchronization: Pthread mutexes, condition variables, reader-writer locks
• Concurrent Request Handling: Thread pools with producer-consumer pattern
• HTTP Protocol: Full HTTP/1.1 support including GET and HEAD methods
• Resource Management: Thread-safe LRU file cache and statistics tracking

## Project Structure
```
webserver-ipc/
├── src/                    # Source code
    ├── main.c              # Program entry point
    ├── Makefile            # Build system
    ├── master.c/h          # Master process implementation
    ├── worker.c/h          # Worker process implementation
    ├── http.c/h            # HTTP request/response handling
    ├── thread_pool.c/h     # Thread pool management
    ├── cache.c/h           # LRU cache implementation
    ├── logger.c/h          # Thread-safe logging
    ├── stats.c/h           # Shared statistics
    └── config.c/h          # Configuration file parser
├── www/                    # Web root directory
    ├── index.html          # Default page
    ├── style.css           # Stylesheets
    ├── script.js           # JavaScript files
    ├── images/             # Image assets
    └── test.html           # Test page
    └── errors/             # Custom error pages
        ├── 404.html
        └── 500.html
├── tests/                  # Test suite
    ├── test_load.sh        # Load testing script
    ├── test_concurrent.c   # Concurrency tests
    └── README.md           # Test documentation
├── docs/                   # Documentation
    ├── design.pdf          # Architecture and design
    ├── report.pdf          # Technical report
    ├── user_manual.pdf     # User guide
    └── README.md           # Docs documentation hahahaha
├── Makefile            # Build system
├── server.conf # Configuration file
└── README.md               # This file
```

## Features
Core Features
• Multi-Process Architecture: 1 master + N workers (default: 4)
• Thread Pools: M threads per worker (default: 10)
• HTTP/1.1 Support: GET and HEAD methods
• Status Codes: 200, 404, 403, 400, 405, 500, 
• MIME Types: HTML, CSS, JavaScript, images (PNG), PDF
• Directory Index: Automatic index.html serving
• Custom Error Pages: Branded 404 and 500 pages

Synchronization Features
• POSIX Semaphores: Inter-process synchronization
• Pthread Mutexes: Thread-level mutual exclusion
• Condition Variables: Producer-consumer queue signaling
• Reader-Writer Locks: Thread-safe file cache access

Advanced Features
• Thread-Safe LRU Cache: 10MB cache per worker with intelligent eviction
• Apache Combined Log Format: Standard logging rotates the log files every 10MB
• Shared Statistics: Real-time request tracking across all workers
• Configuration File: Flexible server.conf for easy customization
• Log Rotation: Automatic rotation at 10MB
• Graceful Shutdown: Proper cleanup on SIGINT/SIGTERM

## Requirements
- **OS:** Linux (Ubuntu 20.04+ recommended)
- **Compiler:** GCC 9.0 or later
- **Libraries:** pthread, rt (realtime)
- **Tools:** make,  (test memory leaks), appache bench (send parallel process), hell grind (test race conditions)
## Quick Start
### Alterations needed 
 - Need to go in config.c and alter document root to the path of your www file

### 1. Compile
```bash
make
```
This will:
- Compile all source files with warnings enabled
- Create the `myserver` executable
### 2. Run Server
```bash
./myserver
```
**Default configuration:**
- Port: 8080
- Workers: 4 processes
- Threads per worker: 4 threads

### Alterations needed


```
### 4. Stop Server
Press `Ctrl+C` in the terminal running the server.
The server will:
- Stop accepting new connections
- Terminate all worker processes gracefully
- Clean up shared memory and semaphores

```
## Architecture
### Process Hierarchy
```
Manager Process (server)
├── Accepts TCP connections
├── Enqueues to shared queue
└── Manages worker processes
│
├── Worker 1
│ ├── Thread 1
│ ├── Thread 2
│ ├── Thread 3
│ ├── Thread 4
│ ├── Thread 5
│ ├── Thread 6
│ ├── Thread 7
│ ├── Thread 8
│ ├── Thread 9
│ └── Thread 10 ── Dequeue and handle requests
│
├── Worker 2
│ └── (same structure as above)
│
└── Worker N...(until worker 4)

- Or in a more simplified way:
Master Process
├── Accepts TCP connections (port 8080)
├── Manages shared memory and semaphores
├── Distributes connections to workers
└── Monitors server statistics
Worker Processes (4 workers)
├── Each maintains a thread pool (10 threads)
├── Threads process HTTP requests
├── Thread-safe LRU file cache
└── Update shared statistics
```
### IPC Mechanisms
**Shared Memory:**
- Structure: `shared_data_t`
- Contains: Connection queue, statistics, shutdown flag
- Created by: Manager process
- Accessed by: Manager + all workers
**Semaphores:**
1. **empty** - Counts empty slots in queue (init: QUEUE_SIZE)
2. **full** - Counts full slots in queue (init: 0)
3. **mutex** - Mutual exclusion for queue access (init: 1)
4. **stats** - Mutual exclusion for statistics (init: 1)
### Synchronization Pattern
**Producer (Manager):**
```c
sem_wait(empty); // Wait for empty slot
sem_wait(mutex); // Lock queue
// Add connection to queue
sem_post(mutex); // Unlock queue
sem_post(full); // Signal full slot
```
**Consumer (Worker threads):**
```c
sem_wait(full); // Wait for full slot
sem_wait(mutex); // Lock queue
// Remove connection from queue
sem_post(mutex); // Unlock queue
sem_post(empty); // Signal empty slot
```
## Testing
### Memory Leak Check
```bash
valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes ./myserver

```
Expected output: "definetely lost 0, indirectly lost 0, possible could be more than 0"
### Race Condition Check
- We advise feeding the output to a file so u can use Ctrl +F to search for the possible race conditions
```bash
valgrind --tool=helgrind ./myserver > helgrind_output.txt 2>&1

```
Expected output: No race conditions reported
### Stress Testing
```bash
# In one terminal
./server
# In another terminal
for i in {1..100}; do
curl -s http://localhost:8080/ > /dev/null &
done
wait
```
### Load Testing with Apache Bench
```bash
# Install if needed: sudo apt-get install apache2-utils
ab -n 1000 -c 50 http://localhost:8080/
```
## Monitoring
The server displays statistics every 30s by using a child process only focused on stats sharing:
```
------ Server Stats ------
Total requests:      0
Bytes transferred:   0
HTTP 200 responses:  0
HTTP 403 responses:  0
HTTP 400 responses:  0
HTTP 405 responses:  0
HTTP 404 responses:  0
HTTP 500 responses:  0
Active connections:  0
--------------------------
```

## Implementation Notes

- Server uses a manager process and multiple worker processes.
- Each worker has 10 threads to handle requests.
- Connections are put in a shared queue using shared memory and semaphores.
- Only `GET` and `HEAD` requests are allowed; others return an error.
- Paths are sanitized so clients can't access files outside the document root.
- Errors send a basic error page or message.
- Logging always uses `127.0.0.1` as the client IP.

### Error Handling

- Send the user to a special error page
- Safe code with alot of prints to let the user know about the errors 
- The server checks for errors at every step (for example: after opening files, reading files, or allocating memory).

### Learning Outcomes
By completing this project, you have demonstrated:
- Understanding of process management and IPC
- Proficiency with thread synchronization primitives
- Ability to design concurrent systems
- Knowledge of network programming
- Skills in debugging multi-threaded programs
- Experience with real-world systems programming

### Known Limitations
1. Hard time implementing graceful shutdown

### Testing
**Manual tests:**
- No race conditions (valgrind helgrind)
- No memory leaks (valgrind memcheck)
- Handles concurrent load (100+ clients)
- Correct HTTP responses (200, 404, 403, 500)
- For more info consult Readme.md present in the tests dir

**Version:** 1.0
**Date:** 15/12/2025