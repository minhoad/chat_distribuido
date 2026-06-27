# Testes de carga e E2E

## REST — 10 usuarios (Gateway)

```powershell
cd load-test
.\run_load_test.ps1                    # sequencial
.\run_load_test.ps1 -Parallel          # 10 logins paralelos (PowerShell 7+)
```

**O que mede:** register/login + `GET /api/history/recipient/sala-geral` via `:8080`.  
**O que NAO mede:** envio STOMP, concorrencia WebSocket, balanceamento multi-instancia.

## E2E — auth + STOMP

```powershell
cd load-test
npm install
npm run e2e
```

**O que mede:** register/login (Gateway) → CONNECT STOMP com JWT → envio GROUP → recebimento no `/topic/group.sala-geral`.  
**Historico REST:** verificacao best-effort apos 3s (pode falhar se Kafka atrasar — entrega STOMP ainda valida integracao).

Variaveis:

```powershell
$env:GATEWAY_URL = "http://localhost:8080"
$env:WS_URL = "http://localhost:8080/ws"
npm run e2e
```

Fallback WS direto no chat:

```powershell
$env:WS_URL = "http://localhost:8082/ws"
npm run e2e
```
