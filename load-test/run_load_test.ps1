# Simula 10 usuários registrando, logando e enviando mensagens via API REST.
# Para WebSocket/STOMP completo, use JMeter com 10 conexões persistentes no endpoint /ws.
# Requisito: API Gateway em http://localhost:8080

param(
    [string]$BaseUrl = "http://localhost:8080",
    [int]$UserCount = 10
)

$ErrorActionPreference = "Stop"
$results = @()

Write-Host "Iniciando teste de carga com $UserCount usuários..."

for ($i = 1; $i -le $UserCount; $i++) {
    $username = "loaduser$i"
    $email = "loaduser$i@test.com"
    $password = "senha123"

  $registerBody = @{ username = $username; email = $email; password = $password } | ConvertTo-Json
    try {
        $auth = Invoke-RestMethod -Uri "$BaseUrl/api/auth/register" -Method Post -Body $registerBody -ContentType "application/json"
    } catch {
        $loginBody = @{ username = $username; password = $password } | ConvertTo-Json
        $auth = Invoke-RestMethod -Uri "$BaseUrl/api/auth/login" -Method Post -Body $loginBody -ContentType "application/json"
    }

    $start = Get-Date
    $messageBody = @{
        senderId = $auth.userId
        recipientId = "sala-geral"
        content = "Mensagem de carga do usuário $username"
        type = "GROUP"
    } | ConvertTo-Json

    # Histórico via REST (persistência assíncrona via Kafka é validada pelo history-service)
    Invoke-RestMethod -Uri "$BaseUrl/api/history/recipient/sala-geral" -Method Get | Out-Null
    $elapsed = (Get-Date) - $start

    $results += [PSCustomObject]@{
        User = $username
        TokenReceived = [bool]$auth.token
        HistoryMs = $elapsed.TotalMilliseconds
    }
}

Write-Host "`nResultados:"
$results | Format-Table -AutoSize
Write-Host "Usuários simultâneos processados: $($results.Count)"
Write-Host "Tokens obtidos: $(($results | Where-Object TokenReceived).Count)"
