#!/bin/bash
# ============================================================================
# Teste de Carga e Funcionalidade para Concurrent HTTP Server
# Requer: curl, ab (Apache Bench)
# ============================================================================

SERVER_EXEC="./server"
CONFIG_FILE="server.conf" # Assumindo que usa server.conf ou config.cfg
PORT=8080
SERVER_URL="http://localhost:${PORT}"
NUM_REQUESTS=10000
CONCURRENCY=100

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# --- Funções de Ajuda ---

# Função para iniciar o servidor em background
start_server() {
    echo -e "${YELLOW}>>> 1. Iniciando o servidor em background...${NC}"
    # Redireciona o output para um ficheiro e guarda o PID
    ${SERVER_EXEC} ${CONFIG_FILE} > server_bg.log 2>&1 &
    SERVER_PID=$!
    if [ -z "$(ps -p $SERVER_PID -o pid=)" ]; then
        echo -e "${RED}ERRO: Servidor não conseguiu iniciar.${NC}"
        return 1
    fi
    sleep 2 # Dá tempo para o servidor inicializar
    echo -e "${GREEN}Servidor iniciado com PID: ${SERVER_PID}${NC}"
    return 0
}

# Função para realizar testes funcionais básicos (200, 404, 403, Content-Type)
functional_tests() {
    echo -e "${YELLOW}>>> 2. Testes Funcionais (Status Codes e MIME Types)${NC}"
    
    # Teste 1: 200 OK e Index Serving (Teste 11)
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" ${SERVER_URL}/)
    if [ "$STATUS" -eq 200 ]; then
        echo -e "${GREEN}[PASS] Index Serving (/) -> 200 OK${NC}"
    else
        echo -e "${RED}[FAIL] Index Serving (/) -> Esperado 200, Obtido ${STATUS}${NC}"
    fi

    # Teste 2: 404 Not Found (Teste 10)
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" ${SERVER_URL}/nao_existe.html)
    if [ "$STATUS" -eq 404 ]; then
        echo -e "${GREEN}[PASS] Ficheiro Inexistente -> 404 Not Found${NC}"
    else
        echo -e "${RED}[FAIL] Ficheiro Inexistente -> Esperado 404, Obtido ${STATUS}${NC}"
    fi
    
    # Teste 3: 403 Forbidden (Directory Traversal - Teste 10)
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" ${SERVER_URL}/../Makefile)
    if [ "$STATUS" -eq 403 ]; then
        echo -e "${GREEN}[PASS] Directory Traversal -> 403 Forbidden${NC}"
    else
        echo -e "${RED}[FAIL] Directory Traversal -> Esperado 403, Obtido ${STATUS}${NC}"
    fi
    
    # Teste 4: Content-Type (Teste 12)
    CTYPE=$(curl -s -I ${SERVER_URL}/style.css | grep -i "Content-Type" | awk '{print $2}' | tr -d '\r')
    if [[ "$CTYPE" == "text/css" ]]; then
        echo -e "${GREEN}[PASS] Content-Type (CSS) -> text/css${NC}"
    else
        echo -e "${RED}[FAIL] Content-Type (CSS) -> Esperado text/css, Obtido ${CTYPE}${NC}"
    fi
}

# Função para realizar testes de carga
load_tests() {
    echo -e "${YELLOW}>>> 3. Teste de Carga (Apache Bench - ${NUM_REQUESTS} requests, ${CONCURRENCY} conc.) (Teste 13, 21)${NC}"
    
    # Executa o Apache Bench
    AB_OUTPUT=$(ab -n ${NUM_REQUESTS} -c ${CONCURRENCY} ${SERVER_URL}/index.html 2>&1)
    
    # Verifica falhas (Teste 14 - Sincronização)
    FAILED=$(echo "$AB_OUTPUT" | grep "Failed requests:" | awk '{print $3}')
    if [ "$FAILED" -eq 0 ]; then
        echo -e "${GREEN}[PASS] Concorrência AB -> 0 Requisições Falhadas${NC}"
    else
        echo -e "${RED}[FAIL] Concorrência AB -> ${FAILED} Requisições Falhadas!${NC}"
    fi

    echo -e "${YELLOW}Desempenho (Requests/sec): $(echo "$AB_OUTPUT" | grep "Requests per second:" | awk '{print $4}') ${NC}"
}

# Função para testar o graceful shutdown e zumbis
shutdown_tests() {
    echo -e "${YELLOW}>>> 4. Teste de Graceful Shutdown (Teste 23, 24)${NC}"
    
    # Envia SIGINT para simular Ctrl+C
    kill -SIGINT $SERVER_PID
    wait $SERVER_PID 2>/dev/null
    
    # Verifica se o processo principal terminou
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[PASS] Servidor Principal -> Terminou com sucesso.${NC}"
    else
        echo -e "${RED}[FAIL] Servidor Principal -> Não terminou corretamente.${NC}"
    fi

    # Verifica por processos zombie
    ZOMBIES=$(ps aux | grep "${SERVER_EXEC}" | grep defunct | wc -l)
    if [ "$ZOMBIES" -eq 0 ]; then
        echo -e "${GREEN}[PASS] Processos Zumbis -> 0 Encontrados.${NC}"
    else
        echo -e "${RED}[FAIL] Processos Zumbis -> ${ZOMBIES} Encontrados! (O Master falhou no waitpid())${NC}"
    fi
}

# --- Execução Principal ---
if ! start_server; then
    exit 1
fi

functional_tests
load_tests
shutdown_tests