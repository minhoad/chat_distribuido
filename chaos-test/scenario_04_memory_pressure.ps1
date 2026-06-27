# Cenario 4: Pressao de memoria no container (alternativa ao Firebase Test Lab para backend Java)
param(
    [string]$Container = "chat-redis",
    [string]$MemoryLimit = "32m"
)

$ErrorActionPreference = "Stop"
Write-Host "=== Cenario 4: Pressao de memoria ($Container limit=$MemoryLimit) ===" -ForegroundColor Cyan
Write-Host "Nota: Firebase Test Lab nao se aplica a Spring Boot; usamos docker update --memory."

$original = docker inspect -f "{{.HostConfig.Memory}}" $Container 2>$null
Write-Host "Memoria original (bytes, 0=sem limite): $original"

Write-Host "`n[1/3] Aplicando limite de memoria..."
docker update --memory $MemoryLimit --memory-swap $MemoryLimit $Container 2>&1 | Out-Null

Write-Host "[2/3] Observando status (15s)..."
Start-Sleep -Seconds 15
$state = docker inspect -f "{{.State.Status}} OOMKilled={{.State.OOMKilled}}" $Container
Write-Host "Estado: $state"

if ($state -match "OOMKilled=True") {
    Write-Host "RESULTADO: container morto por OOM (comportamento esperado sob pressao extrema)" -ForegroundColor Yellow
    docker start $Container | Out-Null
}

Write-Host "`n[3/3] Removendo limite de memoria..."
if ($original -eq "0") {
    docker update --memory 0 --memory-swap 0 $Container | Out-Null
} else {
    docker update --memory $original --memory-swap $original $Container | Out-Null
}

Write-Host "`n--- Resumo ---"
Write-Host "| Teste | Ferramenta | Resultado esperado |"
Write-Host "|-------|------------|-------------------|"
Write-Host "| Estouro memoria | docker update --memory | Degradacao ou OOM + restart manual |"
Write-Host "| Firebase Test Lab | N/A (mobile) | Documentar como fora de escopo do backend |"

$finalState = docker inspect -f "{{.State.Status}}" $Container 2>$null
if ($finalState -ne "running") {
    docker start $Container | Out-Null
    exit 1
}
exit 0
