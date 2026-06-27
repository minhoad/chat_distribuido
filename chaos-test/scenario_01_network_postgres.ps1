# Cenario 1: Tirar a rede do PostgreSQL (simula indisponibilidade do DB de usuarios)
# Mede: auth falha durante outage; recuperacao apos subir postgres + reiniciar auth-service
param(
    [string]$Auth = "http://localhost:8081",
    [int]$WaitRecoverySec = 15
)

$ErrorActionPreference = "Stop"
Write-Host "=== Cenario 1: PostgreSQL indisponivel ===" -ForegroundColor Cyan

Write-Host "`n[1/4] Baseline..."
& "$PSScriptRoot/check_health.ps1" | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Warning "Baseline com falhas - confira se Docker e backends estao rodando." }

Write-Host "`n[2/4] Parando chat-postgres (simula queda de rede/DB)..."
docker stop chat-postgres | Out-Null
Start-Sleep -Seconds 3

Write-Host "[3/4] Testando auth (esperado: falha)..."
$duringOk = $false
try {
    Invoke-RestMethod -Uri "$Auth/api/auth/users" -TimeoutSec 5 | Out-Null
    Write-Host "RESULTADO: INESPERADO - auth respondeu OK com postgres parado" -ForegroundColor Red
    $duringOk = $true
} catch {
    Write-Host "RESULTADO: ESPERADO - auth indisponivel ($($_.Exception.Message))" -ForegroundColor Yellow
}

Write-Host "`n[4/4] Restaurando postgres..."
docker start chat-postgres | Out-Null
Write-Host "Aguardando postgres healthy..."
$deadline = (Get-Date).AddSeconds(30)
do {
    Start-Sleep -Seconds 2
    $state = docker inspect -f "{{.State.Health.Status}}" chat-postgres 2>$null
} while ($state -ne "healthy" -and (Get-Date) -lt $deadline)

Write-Host "IMPORTANTE: reinicie o auth-service (Hikari pode manter pool invalido)." -ForegroundColor Magenta
Write-Host "  PowerShell: feche a janela do auth-service e rode start-backends.ps1 novamente,"
Write-Host "  ou reinicie so auth-service na janela Maven."
Write-Host "Aguardando ${WaitRecoverySec}s antes do check final..."
Start-Sleep -Seconds $WaitRecoverySec

Write-Host "`nCheck pos-recuperacao (pode falhar ate reiniciar auth-service):"
& "$PSScriptRoot/check_health.ps1"

Write-Host "`n--- Resumo para relatorio ---"
Write-Host "| Fase | Auth funciona? |"
Write-Host "|------|----------------|"
Write-Host "| Baseline | Sim (se infra OK) |"
Write-Host "| Postgres parado | $(if ($duringOk) { 'Sim (bug)' } else { 'Nao (esperado)' }) |"
Write-Host "| Postgres restaurado | Reiniciar auth-service necessario |"

if ($duringOk) { exit 1 }
exit 0
