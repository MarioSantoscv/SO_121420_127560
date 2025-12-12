# Test documentation (Documentação da Suite de Testes)
Esta diretoria contém a suite de testes concebida para validar a robustez funcional e concorrente do Concurrent HTTP Server.

Os testes são divididos em dois tipos principais: Testes de Carga e Funcionalidade (Shell Script) e Testes de Sincronização de Baixo Nível (Programa C).

## 1. Pré-requisitos e Setup
Antes de executar qualquer teste, certifique-se de que a build do servidor e do programa de teste está completa e que o ambiente está configurado.

### Requisitos de Ferramentas:
- Apache Bench (ab): Usado para simular alta carga.
- curl: Usado para testes funcionais de requisição HTTP.
- bash: Para execução do script de carga.
- Servidor Compilado: O executável ./server.
- Programa de Teste Compilado: O executável ./tests/test_concurrent.

### Compilação e Setup:
1. Compilar o Servidor e Testes: make all test_concurrent (Isto compila o ./server e o ./tests/test_concurrent.)
2. Configurar o Ambiente (www/ e config.cfg): make setup

## 2. Teste de Carga e Funcionalidade (test_load.sh)
O test_load.sh automatiza os testes de alto nível (HTTP). Ele simula o comportamento de navegadores e ferramentas de carga para validar as funcionalidades básicas, o desempenho sob stress, e os mecanismos de encerramento do servidor.

Execução: bash tests/test_load.sh

### Casos de Teste Incluídos:

## 3. Teste de Sincronização de Baixo Nível (test_concurrent)
Este é um programa C especializado que gera múltiplas threads para abrir e fechar sockets TCP rapidamente. É o método ideal para testar a Fila IPC (Produtor/Consumidor) e a sincronização do Master com os Workers sob grande pressão de conexões.

### Execução:
#### Passo 1: Iniciar o Servidor Abra uma janela de terminal separada e execute o servidor para observar as mensagens de log e estatísticas.
Bash: ./server

#### Passo 2: Executar o Teste de Concorrência Execute o programa, especificando o número total de clientes e a concorrência máxima.

Exemplo: 5000 clientes, 200 a tentar conectar em simultâneo:
Bash: ./tests/test_concurrent 8080 5000 200

Interpretação dos Resultados:

O teste visa stressar a fila do servidor, onde o Master (produtor) insere o socket descriptor e os Workers (consumidores) o retiram.

1. Sucesso Total: O resultado mais importante é: Conexões com Sucesso (200/503): [X] Conexões com Falha/Erro: 0 Onde X é igual ao número total de requisições. Isto prova que o servidor conseguiu lidar com todas as conexões, quer as tenha servido (200 OK), quer as tenha rejeitado porque a fila estava cheia (503 Service Unavailable).

2. Falha de Sincronização: Se o servidor falhar em receber ou responder à conexão (resultando em connection refused ou timeout do lado do cliente), o valor Conexões com Falha/Erro será maior que 0.

## 4. Testes de Integridade (Valgrind e Helgrind)
Estes testes devem ser executados após garantir que os testes funcionais e de carga passam sem erros, para validar a integridade da memória e da sincronização.

### Teste de Fugas de Memória (valgrind)
Bash: make valgrind

- Meta: Simule alguma carga (com ab noutra janela) e depois termine o servidor com Ctrl+C.
- Verificação: O Valgrind deve reportar 0 bytes in 0 blocks are definitely lost e 0 bytes in 0 blocks are possibly lost.

### Teste de Race Conditions (helgrind)
Bash: make helgrind

- Meta: Simule carga.
- Verificação: O Helgrind deve reportar ZERO data races (condições de corrida) não-suprimidas. Se existirem, significa que há acesso a memória partilhada (como a Fila IPC, Estatísticas ou Log) sem a proteção adequada de mutex ou semáforo. 
