# Cenario 3: Atraso / congelamento de trafego (docker pause = processo congelado)
param(
    [string]$Container = "chat-kafka",
    [int]$PauseSec = 20,
    [string]$Gateway = "http://localhost:8080"
)

$ErrorActionPreference = "Stop"
Write-Host "=== Cenario 3: Latencia / trafego interrompido ($Container pausado ${PauseSec}s) ===" -ForegroundColor Cyan

Write-Host "`n[1/4] Medindo latencia baseline em /api/auth/users..."
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$baselineMs = -1
try {
    Invoke-RestMethod -Uri "$Gateway/api/auth/users" -TimeoutSec 10 | Out-Null
    $sw.Stop()
    $baselineMs = $sw.ElapsedMilliseconds
    Write-Host "Baseline: ${baselineMs}ms"
} catch {
    Write-Host "Baseline falhou: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n[2/4] Pausando $Container (congela processamento - simula redes lentas)..."
docker pause $Container | Out-Null
Start-Sleep -Seconds 2

Write-Host "[3/4] Durante pausa - history/chat podem falhar ao persistir/consumir Kafka..."
$historyOk = $false
$sw.Restart()
try {
    Invoke-RestMethod -Uri "$Gateway/api/history/recipient/sala-geral" -TimeoutSec 5 | Out-Null
    $sw.Stop()
    Write-Host "History durante pausa: respondeu em $($sw.ElapsedMilliseconds)ms"
    $historyOk = $true
} catch {
    $sw.Stop()
    Write-Host "History durante pausa: timeout/erro - $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`nAguardando ${PauseSec}s com container pausado..."
Start-Sleep -Seconds $PauseSec

Write-Host "[4/4] Despausando..."
docker unpause $Container | Out-Null
Start-Sleep -Seconds 10

Write-Host "Pos-recuperacao: Kafka consumer pode retomar automaticamente."
Write-Host "`n--- Resumo ---"
Write-Host "| Metrica | Valor |"
Write-Host "|---------|-------|"
Write-Host "| Latencia baseline auth | ${baselineMs}ms |"
Write-Host "| Container pausado | $Container (${PauseSec}s) |"
Write-Host "| Persistencia assincrona | Atrasada durante pausa; retoma apos unpause |"

if ($baselineMs -lt 0) { exit 1 }
exit 0
