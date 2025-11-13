#ifndef MASTER_H
#define MASTER_H

#include "thread_pool.h"

/* Start the master (acceptor) loop.
   - port: port number as string (e.g. "8080")
   - q: initialized connection queue
   Returns 0 on clean shutdown, non-zero on error.
*/
int master_run(const char *port, connection_queue_t *q, int max_clients);

#endif /* MASTER_H */