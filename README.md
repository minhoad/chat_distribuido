# Chat Distribuído — Sistema de mensagens em tempo real

**Alunos:** Darmes Araújo Dias e Gabriel Neri Ferreira Santos  
**Repositório:** https://github.com/minhoad/chat_distribuido.git

## Requisitos

| Ferramenta | Versão |
|------------|--------|
| Java | 21+ (`JAVA_HOME` configurado) |
| Docker | Docker Compose v2 |
| Node.js | 18+ (frontend) |
| Maven | incluso via `./mvnw` / `mvnw.cmd` |

## Subir o projeto (qualquer máquina)

### 1. Infraestrutura (Docker)

```bash
docker compose up -d
# Aguarde ~30s para o Kafka inicializar
```

Volumes nomeados (`postgres_data`, `mongo_data`) — sem caminhos absolutos no host.

### 2. Backend (Java)

**Windows (PowerShell):**

```powershell
$env:JAVA_HOME = "C:\caminho\para\jdk-21"   # ajuste conforme sua instalação
.\start-eureka.ps1                          # aguarde ~10s
.\start-backends.ps1
```

**Linux / macOS:**

```bash
chmod +x run.sh mvnw
./run.sh infra
./run.sh eureka          # terminal 1 — aguarde ~10s
./run.sh backends        # terminal 2 — ou: auth, chat, history, gateway em terminais separados
```

**Makefile (Linux/macOS ou Windows com `make`):**

```bash
make infra
make eureka              # terminal 1
make backends            # Windows: PowerShell; Linux: ./run.sh backends
```

### 3. Frontend

| Modo | Comando | Quando usar |
|------|---------|-------------|
| **Desenvolvimento** | `npm run dev` | Proxy direto em `:8081`, `:8082`, `:8083` — mais estável para WebSocket |
| **Apresentação / demo** | `npm run dev:gateway` | **Todo tráfego via API Gateway `:8080`** — arquitetura final |

```bash
cd frontend
npm install
npm run dev:gateway    # recomendado na entrega/apresentação
```

Atalhos na raiz: `make front-gateway` ou `./run.sh front-gateway`

### 4. Verificação

| URL | Serviço |
|-----|---------|
| http://localhost:8761 | Eureka |
| http://localhost:8080 | API Gateway |
| http://localhost:5173 | Frontend |

## API Gateway — dev vs apresentação

A arquitetura prevê **um único ponto de entrada** (`:8080`). No desenvolvimento diário, o Vite pode contornar o Gateway (proxy direto) por estabilidade do WebSocket. Na **apresentação**, use `npm run dev:gateway` para demonstrar o fluxo real:

```
Frontend → Gateway (:8080) → auth / chat / history (via Eureka)
```

O script de carga (`load-test/run_load_test.ps1` ou `./run.sh load-test`) já usa o Gateway.

## Testes

```bash
./mvnw test              # ou: make test
./run.sh load-test       # 10 usuários REST via Gateway (Windows: load-test/run_load_test.ps1)
```

## Estrutura

```
chat-distribuido/
├── auth-service/      # Autenticação (PostgreSQL)
├── chat-service/      # WebSocket/STOMP (Redis + Kafka)
├── history-service/   # Histórico (MongoDB)
├── api-gateway/       # Entrada única
├── eureka-server/     # Service discovery
├── chat-common/       # Modelos compartilhados
├── frontend/          # React + Vite
├── docker-compose.yml # Infra
├── Makefile           # Atalhos (make help)
└── run.sh             # Atalhos Linux/macOS
```

Documentação completa: [`Relatorio.md`](Relatorio.md)
