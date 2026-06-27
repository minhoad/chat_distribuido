# Chat Distribuído — atalhos de desenvolvimento e entrega
# Requisitos: Java 21+, Docker, Node.js 18+ (para o frontend)

MVNW     := ./mvnw
MVNW_CMD := mvnw.cmd
ROOT     := $(CURDIR)

# Detecta SO para escolher o Maven Wrapper correto
ifeq ($(OS),Windows_NT)
  MVN := $(MVNW_CMD)
else
  MVN := $(MVNW)
endif

.PHONY: help infra infra-down infra-logs build test install-common \
        eureka backends front front-gateway load-test

help: ## Lista comandos disponíveis
	@echo "Chat Distribuído — comandos make"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  %-18s %s\n", $$1, $$2}'
	@echo ""
	@echo "Ordem sugerida para demo/apresentação:"
	@echo "  1. make infra          (Docker: Postgres, Mongo, Redis, Kafka...)"
	@echo "  2. make eureka         (terminal 1 — aguarde ~10s)"
	@echo "  3. make backends       (Windows: abre janelas; Linux: ver run.sh)"
	@echo "  4. make front-gateway  (frontend via API Gateway :8080)"

infra: ## Sobe PostgreSQL, MongoDB, Redis, Kafka (docker compose up -d)
	docker compose up -d
	@echo "Aguarde ~30s para o Kafka inicializar."

infra-down: ## Para e remove containers de infra
	docker compose down

infra-logs: ## Logs dos containers de infra
	docker compose logs -f

install-common: ## Instala chat-common no repositório Maven local
	$(MVN) install -pl chat-common -DskipTests

build: install-common ## Compila todos os módulos (sem testes)
	$(MVN) clean package -DskipTests

test: install-common ## Executa testes automatizados
	$(MVN) test

eureka: install-common ## Inicia Eureka Server (:8761)
	$(MVN) -pl eureka-server spring-boot:run

auth: install-common ## Inicia auth-service (:8081)
	$(MVN) -pl auth-service spring-boot:run

chat: install-common ## Inicia chat-service (:8082)
	$(MVN) -pl chat-service spring-boot:run

history: install-common ## Inicia history-service (:8083)
	$(MVN) -pl history-service spring-boot:run

gateway: install-common ## Inicia api-gateway (:8080)
	$(MVN) -pl api-gateway spring-boot:run

backends: ## Windows: inicia auth, chat, history e gateway (PowerShell)
ifeq ($(OS),Windows_NT)
	powershell -ExecutionPolicy Bypass -File start-backends.ps1
else
	@echo "No Linux/macOS use: ./run.sh backends"
	@echo "Ou abra 4 terminais: make auth | make chat | make history | make gateway"
endif

front: ## Frontend dev (proxy direto nos microsserviços)
	cd frontend && npm install && npm run dev

front-gateway: ## Frontend dev via API Gateway (:8080) — use na apresentação
	cd frontend && npm install && npm run dev:gateway

load-test: ## Teste de carga REST (10 usuários via Gateway)
ifeq ($(OS),Windows_NT)
	powershell -ExecutionPolicy Bypass -File load-test/run_load_test.ps1
else
	./run.sh load-test
endif
