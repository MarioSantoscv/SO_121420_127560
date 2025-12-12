# Test documentation
# Projeto2 - Servidor HTTP Concorrente em C

Este trabalho foi desenvolvido para a disciplina de Sistemas Operativos, com o objetivo de implementar e testar um servidor HTTP concorrente, focando tanto em desempenho como em robustez (síncrona e assinatura segura, gestão de cache, logs, estatísticas e testabilidade).

## Estado da Implementação e Validação

O código **passa com sucesso a todos os testes funcionais e de stress** descritos abaixo (exceto o teste de graceful shutdown):

### **Functional Tests**
- **9. Testa GET requests para vários tipos de ficheiros** (HTML, CSS, JS, imagens):  
  Pedido correto → resposta com o ficheiro pedido.
- **10. Verifica os status HTTP (200, 404, 403, 500):**  
  Cada situação gera o código exato.
- **11. Testa index de diretórios:**  
  Pedidos a `/` servem `index.html` como esperado.
- **12. Verifica Content-Type correto:**  
  Headers HTTP respeitam o tipo do ficheiro.

### **Concurrency Tests**
- **13. Testado com Apache Bench (`ab -n 10000 -c 100`)**:  
  Suporta alta concorrência sem corromper dados.
- **14. Verifica ausência de ligações perdidas:**  
  Nenhuma conexão dropada.
- **15. Testado com múltiplos clientes (`curl`/`wget` em paralelo):**  
  Todas as respostas corretas.
- **16. Estatísticas precisas sob carga:**  
  Contadores correspondem ao número real de pedidos.

### **Synchronization Tests**
- **17. Testado com Helgrind/Thread Sanitizer:**  
  Sem races detetados, testado usando o comando valgrind --tool=helgrind ./myserver > helgrind_output.txt 2>&1, e procurando por Possible Race Conditions neste ficheiro.

- **18. Log file íntegro:**  
  Não há linhas intercaladas ou escritas em simultâneo, e a rotação funciona lindamente
- **19. Consistência do cache garantida em todos os testes paralelos.**
- **20. Contadores de estatísticas estão sempre corretos, sem atualizações perdidas.**
    Sempre corretos e sempre aparecem de 30 em 30s

### **Stress Tests**
- **21. Corre sem problemas durante mais de 5 minutos em carga contínua.**
    Corremos 3050000 pedidos em 5 minutos e todas as responses foram as esperadas
- **22. Sem memory leaks (Valgrind).**
    0 Definetily/Indirectly lost bytes
- **23. O teste de graceful shutdown ainda não está totalmente implementado, pelo que pode ocorrer o fecho abrupto durante requests em andamento (com algumas respostas 404 ou incompletas neste momento).**
- **24. Não ficam processos zombie após o shutdown.**

---

## Testes Automatizados

Além dos testes manuais e de stress acima, fornecemos **dois ficheiros de teste automatizados**, que validam:
- Funcionalidade HTTP (requisições e respostas para diferentes ficheiros/tipos)
- Consistência de cache
- Integridade do log e estatísticas
- Robustez sob concorrência

O código passa ambos os ficheiros de teste sem qualquer falha.

---

## Observações Finais

Este projeto cumpre os requisitos esperados, implementando:
- Thread pool concorrente
- Cache LRU protegida
- Logging e estatísticas seguros em threads
- Proteção contra races (validação contínua)
- Testabilidade (com scripts e benchmarks incluídos)

**Nota:** Falta apenas melhorar a lógica de graceful shutdown para que todos os pedidos em andamento sejam concluídos antes do encerramento completo do servidor.

