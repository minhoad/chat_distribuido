# Relatório — Sistema de Chat Distribuído

**Aluno(s):** Darmes Dias e Gabriel Neri  
**Data:** 26/06/2026  
**Repositório:** https://github.com/minhoad/chat_distribuido

---

## 1. Introdução e Objetivos

Este relatório descreve a implementação de uma plataforma de comunicação em tempo real com arquitetura distribuída, desenvolvida como trabalho prático de Sistemas Distribuídos. O objetivo principal é permitir que múltiplos usuários troquem mensagens instantâneas de forma confiável, atendendo aos requisitos de **alta disponibilidade**, **comunicação em tempo real** e **escalabilidade horizontal**.

A solução adota **Java 21** com **Spring Boot 3.4** no backend, organizada em Maven multi-módulo, e **React + Vite** no frontend. A infraestrutura de apoio (PostgreSQL, MongoDB, Redis, Kafka e Zookeeper/KRaft) é provisionada via **Docker Compose**.

---

## 2. Arquitetura e Decisões de Projeto

### 2.1 Visão geral

O sistema divide responsabilidades em microsserviços independentes, com descoberta de serviços e ponto de entrada único:

```
Frontend (React :5173)
        │
        ▼
API Gateway (:8080) ──► Eureka Server (:8761)
        │
        ├── auth-service (:8081) ──► PostgreSQL (usuários)
        ├── chat-service (:8082) ──► Redis (Pub/Sub + presença)
        │         │
        │         └── Kafka ──► history-service (:8083) ──► MongoDB (mensagens)
        └── history-service (:8083) ◄── REST (leitura de histórico)
```

| Componente | Tecnologia | Justificativa |
|------------|------------|---------------|
| Linguagem / runtime | Java 21 + Spring Boot 3.4 | Ecossistema maduro, suporte a Virtual Threads |
| Autenticação | Spring Security + JWT (stateless) | Escalável; token compartilhado entre HTTP e WebSocket |
| Tempo real | WebSocket + STOMP (SockJS) | Push persistente exigido pelo edital |
| Escrita de mensagens | `chat-service` | Recebe via STOMP, publica em Redis e Kafka |
| Leitura de histórico | `history-service` | REST sobre MongoDB (CQRS leve) |
| DB relacional | PostgreSQL | Consistência para usuários e credenciais |
| DB NoSQL | MongoDB | Escrita rápida e schema flexível para mensagens |
| Comunicação assíncrona | Apache Kafka | Desacopla entrega em tempo real da persistência |
| Distribuição entre instâncias | Redis Pub/Sub | Roteia mensagens entre réplicas do `chat-service` |
| Descoberta / balanceamento | Netflix Eureka + Spring Cloud Gateway | Registro dinâmico e roteamento `lb://` |
| Contrato compartilhado | Módulo `chat-common` | Evita divergência de serialização Kafka entre serviços |
| Concorrência I/O | Virtual Threads (`spring.threads.virtual.enabled=true`) | Suporta muitas conexões WebSocket com código síncrono |

### 2.2 Separação escrita vs. leitura

Adotou-se um padrão **CQRS leve**:

- **Escrita:** o cliente envia mensagem via STOMP (`/app/chat.send`); o `chat-service` valida o remetente, publica no Redis (entrega imediata) e no Kafka (persistência assíncrona).
- **Leitura:** o frontend consulta `GET /api/history/conversation/{userId}/{peerId}` ou `GET /api/history/recipient/{groupId}` ao abrir uma conversa.

Essa separação evita que operações de banco bloqueiem a entrega em tempo real.

### 2.3 Fluxo de uma mensagem privada (1:1)

1. Usuário A envia payload JSON via STOMP para `/app/chat.send`.
2. O interceptor WebSocket valida o JWT no `CONNECT` e associa a sessão ao `userId`.
3. O `ChatController` confere se `senderId` coincide com o usuário autenticado.
4. A mensagem é publicada no canal Redis `chat:global`.
5. Cada instância do `chat-service` inscrita recebe o evento e entrega via `convertAndSendToUser` para remetente e destinatário (`/user/queue/messages`).
6. Em paralelo, a mensagem é enviada ao tópico Kafka `chat-messages`.
7. O `history-service` consome e persiste no MongoDB.

### 2.4 Mensagens em grupo (1:N)

Grupos são identificados por `recipientId` (ex.: `sala-geral`, `projeto-sd`) com `type: GROUP`. A entrega usa broadcast STOMP em `/topic/group.{groupId}`. O histórico de grupo é recuperado por `GET /api/history/recipient/{groupId}`. Os grupos são **fixos no frontend** — não há CRUD de salas no backend.

### 2.5 Limitações arquiteturais reconhecidas

- **Alta disponibilidade:** Eureka, Gateway e Redis permitem réplicas, mas **não foi executado teste automatizado de failover** (ex.: derrubar uma instância e medir recuperação).
- **Escalabilidade horizontal:** o mecanismo Redis Pub/Sub está implementado, porém **não foi demonstrado empiricamente** com duas instâncias do `chat-service` em execução simultânea.
- **Ambiente de desenvolvimento:** o Vite faz proxy direto para `:8081`, `:8082` e `:8083`, contornando o Gateway; em produção, o tráfego deveria passar exclusivamente por `:8080`.
- **Grupos:** sem gestão dinâmica de membros ou permissões.

---

## 3. Implementação

### 3.1 Serviço de Autenticação (`auth-service`)

Responsável pelo ciclo de vida do usuário:

| Endpoint | Descrição |
|----------|-----------|
| `POST /api/auth/register` | Cadastro com validação (senha 6–100 caracteres) |
| `POST /api/auth/login` | Autenticação; retorna JWT |
| `GET /api/auth/users` | Lista usuários para seleção de conversas |

Senhas armazenadas com **BCrypt**. Erros expostos em formato padronizado (`ApiError`) com mensagens amigáveis (ex.: senha curta → HTTP 400 com texto explicativo).

### 3.2 Serviço de Chat (`chat-service`)

- Endpoint WebSocket: `/ws` (SockJS + STOMP).
- Destinos: `/app/chat.send` (entrada), `/user/queue/messages` (privado), `/topic/group.*` (grupo).
- Autenticação STOMP via header `Authorization: Bearer {token}` no `CONNECT`.
- `PresenceService` registra sessões no Redis (`user:session:*`, `user:online:*`).

### 3.3 Serviço de Histórico (`history-service`)

- Consumer Kafka persiste `ChatMessage` como `ChatMessageDocument` no MongoDB.
- Consultas: conversa bidirecional 1:1 (`findConversation`) e mensagens por destinatário/grupo.

**Correção relevante:** inicialmente, producer e consumer usavam classes diferentes no Kafka, o que impedia a persistência. Foi criado o módulo `chat-common` e desabilitado o header de tipo na serialização, restaurando o fluxo de gravação.

### 3.4 Frontend (`frontend/`)

Interface responsiva (CSS com `@media (max-width: 768px)`) contendo:

- Tela de login/registro.
- Sidebar com lista de usuários (atualizada a cada 15 s via HTTP) e grupos pré-definidos.
- Área de mensagens com envio por Enter ou botão.
- Indicador de conexão WebSocket (`conectado` / `desconectado`).
- Exibição de erros de chat e de histórico.

O chat em tempo real **não utiliza polling HTTP** — mensagens novas chegam exclusivamente via STOMP. O histórico é carregado uma vez ao selecionar conversa ou grupo.

---

## 4. Testes e Avaliação

### 4.1 Testes automatizados

Execução: `.\mvnw.cmd test` (Java 21). **9 testes, 0 falhas** (verificado em 26/06/2026).

| Módulo | Classe | Tipo | O que cobre |
|--------|--------|------|-------------|
| `auth-service` | `AuthServiceTest` | Unitário | Login válido/inválido, registro |
| `auth-service` | `JwtServiceTest` | Unitário | Geração e validação de token |
| `auth-service` | `AuthIntegrationTest` | Integração | Fluxo register → login via MockMvc (H2 em memória) |
| `history-service` | `HistoryServiceTest` | Unitário | Persistência e ordenação de conversa |

**Lacunas honestas:**

- **`chat-service` não possui testes automatizados** (WebSocket, Redis, Kafka).
- **Não há teste de integração ponta-a-ponta** (login → envio STOMP → verificação no MongoDB).
- Integração do auth usa **H2**, não PostgreSQL real (sem Testcontainers).

### 4.2 Testes manuais (estudos de caso funcionais)

| Cenário | Procedimento | Resultado observado |
|---------|--------------|---------------------|
| Registro e login | Dois usuários em abas distintas | Tokens distintos; lista de usuários atualizada |
| Chat 1:1 | Selecionar peer, enviar mensagens | Entrega em tempo real para ambos; histórico ao reabrir conversa |
| Chat 1:N | Enviar na "Sala Geral" | Todos os conectados ao tópico recebem; histórico via `/recipient/sala-geral` |
| Validação de senha | Registrar com senha &lt; 6 caracteres | HTTP 400 com mensagem amigável |
| Infra indisponível | Kafka/MongoDB parados | Chat em tempo real via Redis funciona; histórico falha ou retorna vazio |

### 4.3 Teste de concorrência/carga

Existe o script `load-test/run_load_test.ps1`, que registra/loga **10 usuários** via REST no Gateway e consulta histórico de grupo.

**Limitações do script atual (importante para avaliação honesta):**

| Aspecto | Situação |
|---------|----------|
| Usuários simultâneos | Loop **sequencial**, não paralelo — não simula concorrência real |
| Envio de mensagens | **Não abre WebSocket** — não envia mensagens de chat |
| Balanceamento de carga | **Não exercita** múltiplas instâncias do `chat-service` |
| Escalabilidade horizontal | Mecanismo implementado (Redis), mas **não comprovado numericamente** |

Para atender plenamente o requisito de carga com 10 usuários trocando mensagens, seria necessário complementar com **JMeter/Gatling** (10 conexões STOMP persistentes com JWT) ou paralelizar o script e incluir publicação STOMP. **Esse complemento ainda não foi executado e documentado com métricas.**

### 4.4 Matriz de conformidade com o edital

| Requisito | Atendido | Observação |
|-----------|----------|------------|
| ≥ 2 microsserviços | Sim | auth, chat, history (+ gateway, eureka) |
| WebSocket tempo real | Sim | STOMP/SockJS |
| DB usuários + mensagens | Sim | PostgreSQL + MongoDB |
| Frontend responsivo | Sim | React com layout adaptável |
| Mensagens 1:1 e 1:N | Sim | PRIVATE e GROUP |
| Persistência de histórico | Sim | Kafka → MongoDB (após correção do contrato) |
| Testes unitários | Parcial | auth e history; chat sem testes |
| Testes de integração | Parcial | auth HTTP; sem fluxo auth→chat→history |
| Teste carga 10 usuários | Parcial | script REST sequencial; sem WebSocket concorrente |
| Alta disponibilidade comprovada | Não testado | infraestrutura preparada, sem cenário de falha |
| Escalabilidade horizontal comprovada | Não testado | Redis Pub/Sub implementado, sem demo multi-instância |

---

## 5. Conclusões

1. Foi construída uma arquitetura distribuída funcional, com separação clara entre autenticação, mensageria em tempo real e persistência de histórico, utilizando PostgreSQL, MongoDB, Redis, Kafka, Eureka e API Gateway.

2. A escolha de **Virtual Threads** e **STOMP sobre WebSocket** equilibra simplicidade de implementação e capacidade de atender muitas conexões simultâneas.

3. O módulo **`chat-common`** e a correção da serialização Kafka foram decisivas para que a persistência funcionasse de fato — antes disso, mensagens apareciam em tempo real, mas o histórico permanecia vazio.

4. Os **testes automatizados cobrem a lógica central de autenticação e histórico**, porém o **`chat-service` e o fluxo integrado completo carecem de cobertura**.

5. O **teste de carga existente valida registro/login em lote**, mas **não substitui** o estudo de caso de 10 usuários simultâneos trocando mensagens via WebSocket — ponto a reforçar antes da apresentação.

6. Para demonstração em sala, recomenda-se: subir infra (`docker compose up -d`), iniciar serviços na ordem Eureka → backends → Gateway → frontend, registrar dois usuários e validar chat privado, grupo e recarga de histórico.

---

## Referências

1. Spring Boot 3.4 Documentation — https://docs.spring.io/spring-boot/docs/current/reference/html/
2. Spring WebSocket/STOMP — https://docs.spring.io/spring-framework/reference/web/websocket.html
3. Apache Kafka Documentation — https://kafka.apache.org/documentation/
4. Redis Pub/Sub — https://redis.io/docs/interact/pubsub/
5. Spring Cloud Netflix Eureka — https://spring.io/projects/spring-cloud-netflix
