#!/usr/bin/env bash
# Chat Distribuído — script de execução (Linux/macOS/Git Bash)
# Uso: ./run.sh [comando]
# Windows PowerShell: use start-eureka.ps1 / start-backends.ps1

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

MVN_MODE=""
MVN_BIN=""

resolve_mvn() {
  if [ -f "./mvnw.cmd" ] && command -v cmd.exe >/dev/null 2>&1; then
    MVN_MODE="cmd"
    return
  fi

  if [ -x "./mvnw" ]; then
    MVN_BIN="./mvnw"
  elif [ -f "./mvnw" ]; then
    chmod +x ./mvnw 2>/dev/null || true
    MVN_BIN="./mvnw"
  elif command -v mvn >/dev/null 2>&1; then
    MVN_BIN="mvn"
  else
    echo "Erro: Maven Wrapper não encontrado (mvnw / mvnw.cmd)."
    exit 1
  fi
}

# Executa Maven Wrapper (cmd.exe no Git Bash; ./mvnw no Linux/macOS)
run_mvn() {
  if [ "$MVN_MODE" = "cmd" ]; then
    # cmd.exe //c exige um único argumento após //c
    cmd.exe //c "mvnw.cmd $*"
  else
    "$MVN_BIN" "$@"
  fi
}

resolve_mvn

require_java() {
  if ! command -v java >/dev/null 2>&1; then
    echo "Erro: Java não encontrado. Instale Java 21+ e configure JAVA_HOME."
    exit 1
  fi
}

require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "Erro: Docker não encontrado."
    exit 1
  fi
}

install_common() {
  require_java
  echo ">> Instalando chat-common..."
  run_mvn install -pl chat-common -DskipTests -q
}

cmd_help() {
  cat <<'EOF'
Chat Distribuído — ./run.sh [comando]

Comandos:
  infra           Sobe Docker (Postgres, Mongo, Redis, Kafka...)
  infra-down      Para containers de infra
  infra-logs      Logs da infra
  build           Compila todos os módulos
  test            Roda testes Maven
  eureka          Inicia Eureka (:8761)
  auth            Inicia auth-service (:8081)
  chat            Inicia chat-service (:8082)
  history         Inicia history-service (:8083)
  gateway         Inicia api-gateway (:8080)
  backends        Inicia auth, chat, history e gateway em background
  front           Frontend dev (proxy direto)
  front-gateway   Frontend dev via Gateway (:8080) — apresentação
  load-test       Teste de carga REST (10 usuários)
  help            Esta ajuda

Ordem sugerida:
  1. ./run.sh infra
  2. ./run.sh eureka          (terminal 1, aguarde ~10s)
  3. ./run.sh backends        (ou 4 terminais: auth, chat, history, gateway)
  4. ./run.sh front-gateway
EOF
}

cmd_infra() {
  require_docker
  docker compose up -d
  echo "Aguarde ~30s para o Kafka inicializar."
}

cmd_infra_down() {
  require_docker
  docker compose down
}

cmd_infra_logs() {
  require_docker
  docker compose logs -f
}

cmd_build() {
  install_common
  run_mvn clean package -DskipTests
}

cmd_test() {
  install_common
  run_mvn test
}

start_service_bg() {
  local module="$1"
  local port="$2"
  local log_file="$ROOT/logs/${module}.log"
  mkdir -p "$ROOT/logs"
  echo ">> Iniciando $module (porta $port) — log: $log_file"
  nohup run_mvn -pl "$module" spring-boot:run >"$log_file" 2>&1 &
  echo $! >"$ROOT/logs/${module}.pid"
}

cmd_backends() {
  require_java
  install_common

  if [ "$MVN_MODE" = "cmd" ]; then
    echo ">> Windows detectado — usando start-backends.ps1 (janelas separadas)"
    local win_root="${WIN_ROOT:-$(pwd -W)}"
    local ps_cmd="Set-Location '$win_root'; & '.\start-backends.ps1'"
    if [ -n "${JAVA_HOME:-}" ]; then
      local win_java="$JAVA_HOME"
      if command -v cygpath >/dev/null 2>&1; then
        win_java="$(cygpath -w "$JAVA_HOME")"
      elif [ -d "$JAVA_HOME" ]; then
        win_java="$(cd "$JAVA_HOME" && pwd -W 2>/dev/null || echo "$JAVA_HOME")"
      fi
      ps_cmd="\$env:JAVA_HOME='$win_java'; $ps_cmd"
    fi
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ps_cmd"
    return
  fi

  echo ">> Iniciando microsserviços em background (logs em ./logs/)"
  start_service_bg auth-service 8081
  sleep 3
  start_service_bg chat-service 8082
  sleep 3
  start_service_bg history-service 8083
  sleep 3
  start_service_bg api-gateway 8080
  echo ""
  echo "Serviços iniciados. Aguarde ~30s e verifique:"
  echo "  http://localhost:8761  (Eureka — inicie ./run.sh eureka antes, se ainda não estiver rodando)"
  echo "  http://localhost:8080  (Gateway)"
  echo "  http://localhost:8081  (Auth)"
  echo "  http://localhost:8082  (Chat)"
  echo "  http://localhost:8083  (History)"
  echo ""
  echo "Para parar: kill \$(cat logs/*.pid)"
}

cmd_front() {
  cd frontend
  npm install --legacy-peer-deps
  npm run dev
}

cmd_front_gateway() {
  cd frontend
  npm install --legacy-peer-deps
  npm run dev:gateway
}

cmd_load_test() {
  local base_url="${BASE_URL:-http://localhost:8080}"
  local count="${USER_COUNT:-10}"
  echo ">> Teste de carga REST: $count usuários em $base_url"
  for i in $(seq 1 "$count"); do
    username="loaduser$i"
    email="loaduser$i@test.com"
    password="senha123"
    auth=$(curl -sf -X POST "$base_url/api/auth/register" \
      -H "Content-Type: application/json" \
      -d "{\"username\":\"$username\",\"email\":\"$email\",\"password\":\"$password\"}" 2>/dev/null \
      || curl -sf -X POST "$base_url/api/auth/login" \
      -H "Content-Type: application/json" \
      -d "{\"username\":\"$username\",\"password\":\"$password\"}")
    curl -sf "$base_url/api/history/recipient/sala-geral" >/dev/null
    echo "  OK: $username (token recebido)"
  done
  echo ">> Concluído: $count usuários processados via Gateway"
}

case "${1:-help}" in
  infra)          cmd_infra ;;
  infra-down)     cmd_infra_down ;;
  infra-logs)     cmd_infra_logs ;;
  build)          cmd_build ;;
  test)           cmd_test ;;
  install-common) install_common ;;
  eureka)         install_common; run_mvn -pl eureka-server spring-boot:run ;;
  auth)           install_common; run_mvn -pl auth-service spring-boot:run ;;
  chat)           install_common; run_mvn -pl chat-service spring-boot:run ;;
  history)        install_common; run_mvn -pl history-service spring-boot:run ;;
  gateway)        install_common; run_mvn -pl api-gateway spring-boot:run ;;
  backends)       cmd_backends ;;
  front)          cmd_front ;;
  front-gateway)  cmd_front_gateway ;;
  load-test)      cmd_load_test ;;
  help|-h|--help) cmd_help ;;
  *)
    echo "Comando desconhecido: $1"
    cmd_help
    exit 1
    ;;
esac
