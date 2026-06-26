# Inicia cada microsserviço em uma nova janela do PowerShell.
# Pré-requisito: Eureka já rodando (porta 8761) e JAVA_HOME configurado.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$javaHome = if ($env:JAVA_HOME) { $env:JAVA_HOME } else { "D:\java" }

$services = @(
    @{ Name = "auth-service";    Port = 8081 },
    @{ Name = "chat-service";    Port = 8082 },
    @{ Name = "history-service"; Port = 8083 },
    @{ Name = "api-gateway";     Port = 8080 }
)

foreach ($svc in $services) {
    $title = $svc.Name
    $module = $svc.Name
  Write-Host "Iniciando $title (porta $($svc.Port))..."
    Start-Process powershell -ArgumentList @(
        "-NoExit",
        "-Command",
        "`$env:JAVA_HOME='$javaHome'; Set-Location '$root'; .\mvnw.cmd -pl $module spring-boot:run"
    )
    Start-Sleep -Seconds 3
}

Write-Host ""
Write-Host "Serviços iniciados em janelas separadas."
Write-Host "Aguarde ~30s e verifique:"
Write-Host "  - http://localhost:8761  (Eureka)"
Write-Host "  - http://localhost:8080  (Gateway)"
Write-Host "  - http://localhost:8081  (Auth)"
Write-Host "  - http://localhost:8082  (Chat)"
Write-Host "  - http://localhost:8083  (History)"
Write-Host ""
Write-Host "Frontend: cd frontend && npm install && npm run dev"
