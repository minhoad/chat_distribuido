# Cenario 2: Redis indisponivel - afeta Pub/Sub entre instancias; chat local pode degradar
param(
    [string]$Gateway = "http://localhost:8080",
    [string]$Auth = "http://localhost:8081"
)

$ErrorActionPreference = "Stop"
Write-Host "=== Cenario 2: Redis indisponivel ===" -ForegroundColor Cyan

Write-Host "`n[1/4] Parando chat-redis..."
docker stop chat-redis | Out-Null
Start-Sleep -Seconds 3

Write-Host "[2/4] Auth direto ainda responde? (auth nao depende de Redis)"
$authDirectOk = $false
try {
    Invoke-RestMethod -Uri "$Auth/api/auth/users" -TimeoutSec 10 | Out-Null
    Write-Host "Auth direto :8081: OK (esperado)" -ForegroundColor Green
    $authDirectOk = $true
} catch {
    Write-Host "Auth direto :8081: FALHOU - $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "[3/4] Gateway ainda responde auth?"
$authGatewayOk = $false
try {
    Invoke-RestMethod -Uri "$Gateway/api/auth/users" -TimeoutSec 10 | Out-Null
    Write-Host "Auth via Gateway: OK (esperado - Redis nao e usado pelo auth)" -ForegroundColor Green
    $authGatewayOk = $true
} catch {
    Write-Host "Auth via Gateway: FALHOU - $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n[4/4] Chat-service: envio/recebimento em tempo real provavelmente FALHA"
Write-Host "  (Redis Pub/Sub indisponivel). Teste manual: enviar mensagem no frontend."
Write-Host "  Esperado: conectado mas mensagens nao propagam."

Write-Host "`nRestaurando redis..."
docker start chat-redis | Out-Null
Start-Sleep -Seconds 5
Write-Host "Redis restaurado. Reconecte WebSocket (recarregue pagina) se necessario."

Write-Host "`n--- Resumo ---"
Write-Host "| Componente | Com Redis parado |"
Write-Host "|------------|------------------|"
Write-Host "| auth-service | Normal |"
Write-Host "| chat tempo real | Degradado/falha |"
Write-Host "| history (Kafka->Mongo) | Normal se Kafka/Mongo OK |"

if (-not $authDirectOk) { exit 1 }
exit 0
