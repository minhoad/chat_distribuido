# Executa cenarios de caos/disponibilidade (requer Docker + backends rodando)
param([switch]$SkipMemory)

$ErrorActionPreference = "Continue"
$root = $PSScriptRoot
$failures = @()

function Invoke-Scenario {
    param([string]$Name, [string]$Script)
    Write-Host "`n========================================" -ForegroundColor Cyan
    & $Script
    if ($LASTEXITCODE -ne 0) {
        $script:failures += $Name
        Write-Host "Cenario $Name terminou com codigo $LASTEXITCODE" -ForegroundColor Yellow
    }
}

Write-Host "Pre-requisito: docker compose up -d && Eureka + backends rodando`n" -ForegroundColor Cyan

& "$root/check_health.ps1"
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Health check inicial falhou. Continuando mesmo assim..."
}
Write-Host ""

Invoke-Scenario -Name "01_postgres" -Script "$root/scenario_01_network_postgres.ps1"
Start-Sleep -Seconds 5

Invoke-Scenario -Name "02_redis" -Script "$root/scenario_02_network_redis.ps1"
Start-Sleep -Seconds 3

Invoke-Scenario -Name "03_kafka_pause" -Script "$root/scenario_03_latency_pause.ps1"
Start-Sleep -Seconds 3

if (-not $SkipMemory) {
    Invoke-Scenario -Name "04_memory" -Script "$root/scenario_04_memory_pressure.ps1"
}

Write-Host "`nCheck final de saude..."
& "$root/check_health.ps1"
$healthOk = ($LASTEXITCODE -eq 0)

Write-Host "`n=== Cenarios concluidos ===" -ForegroundColor Green
if ($failures.Count -gt 0) {
    Write-Host "Cenarios com falha: $($failures -join ', ')" -ForegroundColor Yellow
}
if (-not $healthOk) {
    Write-Host "Health check final falhou - verifique auth-service apos cenario postgres." -ForegroundColor Yellow
}

if ($failures.Count -gt 0 -or -not $healthOk) {
    exit 1
}
Write-Host "Todos os cenarios executados com sucesso."
exit 0
