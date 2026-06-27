# Teste de carga REST via API Gateway: register/login + GET historico de grupo.
# NAO envia mensagens STOMP — para auth->chat use: node e2e_auth_stomp.mjs
# Requisito: Gateway em http://localhost:8080 (Eureka + auth + history UP)

param(
    [string]$BaseUrl = "http://localhost:8080",
    [int]$UserCount = 10,
    [switch]$Parallel
)

$ErrorActionPreference = "Stop"

function Invoke-LoadUser {
    param([int]$Index, [string]$Base)

    $username = "loaduser$Index"
    $email = "loaduser$Index@test.com"
    $password = "senha123"

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $registerBody = @{ username = $username; email = $email; password = $password } | ConvertTo-Json
    try {
        $auth = Invoke-RestMethod -Uri "$Base/api/auth/register" -Method Post -Body $registerBody -ContentType "application/json"
    } catch {
        $loginBody = @{ username = $username; password = $password } | ConvertTo-Json
        $auth = Invoke-RestMethod -Uri "$Base/api/auth/login" -Method Post -Body $loginBody -ContentType "application/json"
    }

    Invoke-RestMethod -Uri "$Base/api/history/recipient/sala-geral" -Method Get | Out-Null
    $sw.Stop()

    [PSCustomObject]@{
        User          = $username
        TokenReceived = [bool]$auth.token
        TotalMs       = [math]::Round($sw.Elapsed.TotalMilliseconds, 1)
    }
}

Write-Host "Teste de carga REST: $UserCount usuarios em $BaseUrl"
Write-Host "Modo: $(if ($Parallel) { 'paralelo' } else { 'sequencial' })"
Write-Host ""

$totalSw = [System.Diagnostics.Stopwatch]::StartNew()

if ($Parallel) {
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $results = 1..$UserCount | ForEach-Object -Parallel {
            $idx = $_
            $base = $using:BaseUrl
            $username = "loaduser$idx"
            $email = "loaduser$idx@test.com"
            $password = "senha123"
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $registerBody = @{ username = $username; email = $email; password = $password } | ConvertTo-Json
            try {
                $auth = Invoke-RestMethod -Uri "$base/api/auth/register" -Method Post -Body $registerBody -ContentType "application/json"
            } catch {
                $loginBody = @{ username = $username; password = $password } | ConvertTo-Json
                $auth = Invoke-RestMethod -Uri "$base/api/auth/login" -Method Post -Body $loginBody -ContentType "application/json"
            }
            Invoke-RestMethod -Uri "$base/api/history/recipient/sala-geral" -Method Get | Out-Null
            $sw.Stop()
            [PSCustomObject]@{
                User          = $username
                TokenReceived = [bool]$auth.token
                TotalMs       = [math]::Round($sw.Elapsed.TotalMilliseconds, 1)
            }
        } -ThrottleLimit $UserCount
    } else {
        Write-Host "PowerShell 5: paralelo via Start-Job..."
        $jobs = @()
        for ($i = 1; $i -le $UserCount; $i++) {
            $idx = $i
            $jobs += Start-Job -ArgumentList $idx, $BaseUrl -ScriptBlock {
                param($Index, $Base)
                $username = "loaduser$Index"
                $email = "loaduser$Index@test.com"
                $password = "senha123"
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                $registerBody = @{ username = $username; email = $email; password = $password } | ConvertTo-Json
                try {
                    $auth = Invoke-RestMethod -Uri "$Base/api/auth/register" -Method Post -Body $registerBody -ContentType "application/json"
                } catch {
                    $loginBody = @{ username = $username; password = $password } | ConvertTo-Json
                    $auth = Invoke-RestMethod -Uri "$Base/api/auth/login" -Method Post -Body $loginBody -ContentType "application/json"
                }
                Invoke-RestMethod -Uri "$Base/api/history/recipient/sala-geral" -Method Get | Out-Null
                $sw.Stop()
                [PSCustomObject]@{
                    User          = $username
                    TokenReceived = [bool]$auth.token
                    TotalMs       = [math]::Round($sw.Elapsed.TotalMilliseconds, 1)
                }
            }
        }
        $results = $jobs | Wait-Job | Receive-Job
        $jobs | Remove-Job -Force
    }
} else {
    $results = @()
    for ($i = 1; $i -le $UserCount; $i++) {
        $results += Invoke-LoadUser -Index $i -Base $BaseUrl
    }
}

$totalSw.Stop()

Write-Host "Resultados por usuario:"
$results | Sort-Object User | Format-Table -AutoSize

$tokens = ($results | Where-Object TokenReceived).Count
Write-Host "Usuarios processados: $($results.Count)"
Write-Host "Tokens obtidos:       $tokens/$UserCount"
Write-Host "Tempo total (parede): $([math]::Round($totalSw.Elapsed.TotalMilliseconds, 0)) ms"
if ($results.Count -gt 0) {
    $avg = ($results | Measure-Object -Property TotalMs -Average).Average
    Write-Host "Latencia media/user:  $([math]::Round($avg, 1)) ms (register/login + GET historico)"
}

if ($tokens -ne $UserCount) { exit 1 }
exit 0
