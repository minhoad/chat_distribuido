Relatório TP Final - Chat distribuído
Aluno(s): Darmes Araújo Dias e Gabriel Neri Ferreira Santos
Data: 26/06/2026
Repositório: https://github.com/minhoad/chat_distribuido.git
1. Introdução 
2. Decisões de Projeto
   2.1 Microsserviços
       2.1.1 Serviço de autenticação/usuário
       A linguagem escolhida para tal foi o Java para fazer todo este microsserviço, tanto o registro, quanto a possibilidade de login e o controle de autenticação dos usuários.
       2.1.2 Serviço de mensagens/chat
       O serviço de chat também foi construído em Java, o envio, o recebimento, o armazenamento e a transmissão de mensagens em tempo real.
   2.2 Comunicação Assíncrona (Tempo Real)
   A seção src do código é a responsável pelo histórico do chat e também o tempo de transição entre o envio e o recebimento da mensagem.
   2.3 Banco de Dados
   O Mongo foi utilizado como o banco de dados relacional para coletar os dados de usuários. Por sua vez, a otimização da leitura e da escrita de chats ficou com os Postgres. 
3. Estrutura do código
4. Resultados dos testes
   4.1 Testes unitários
   4.2 Testes de integração
       4.2.1 Comunicação entre o Serviço de Autenticação e o Serviço de Mensagens
       4.2.2 Comunicação do Front-end com os serviços de backend
   4.3 Teste de concorrência/carga
5. Análise
6. Conclusões
   Alta disponibilidade:
   Comunicação em tempo real:
   Escalabilidade horizontal:
Referências
