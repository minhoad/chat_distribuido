# Subir Eureka em janela separada
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $env:JAVA_HOME) {
    Write-Warning "JAVA_HOME não definido. Configure Java 21+ antes de continuar."
    exit 1
}

Write-Host "Iniciando eureka-server (porta 8761)..."
Start-Process powershell -ArgumentList @(
    "-NoExit",
    "-Command",
    "`$env:JAVA_HOME='$env:JAVA_HOME'; Set-Location '$root'; .\mvnw.cmd -pl eureka-server spring-boot:run"
)

Start-Sleep -Seconds 8
Write-Host "Eureka iniciado. Agora rode: .\start-backends.ps1"
