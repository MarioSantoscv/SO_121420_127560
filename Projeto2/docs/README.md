# Documentação do Projeto
Esta diretoria contém a documentação formal e técnica do projeto Concurrent HTTP Server, desenvolvido no âmbito da Unidade Curricular de Sistemas Operativos 2025/2026.

A documentação está dividida em três secções principais: Design Arquitetural, Manual do Utilizador e Relatório Técnico.

## 1. Relatório Técnico e Design Arquitetural

### O Relatório Técnico (report.pdf): 
É o documento chave que descreve a arquitetura, as decisões de design e a implementação dos mecanismos de concorrência.

### Design Arquitetural (design.pdf): 
Este documento foca-se nos diagramas e na descrição de alto nível das estruturas de dados principais, sendo um resumo visual do Relatório Técnico.
- Diagrama de Arquitetura: Diagrama de fluxo de dados (requisição, Master, Fila IPC, Worker, Thread).
- Estruturas de Dados: Representação da estrutura da Fila IPC e das Estruturas de Memória Partilhada.

## 2. Manual do Utilizador (user_manual.pdf)
O Manual do Utilizador destina-se a qualquer pessoa que precise de compilar, configurar ou executar o servidor.

## 3. Estrutura de Diretoria
docs/
├── README.md               <-- ESTE FICHEIRO (Índice da Documentação)
├── design.pdf              <-- Diagramas e Visão Arquitetural
├── report.pdf              <-- Relatório Técnico Completo
└── user_manual.pdf         <-- Guia de Utilização e Configuração