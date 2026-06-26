# Subir Eureka em janela separada
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$javaHome = if ($env:JAVA_HOME) { $env:JAVA_HOME } else { "D:\java" }

Write-Host "Iniciando eureka-server (porta 8761)..."
Start-Process powershell -ArgumentList @(
    "-NoExit",
    "-Command",
    "`$env:JAVA_HOME='$javaHome'; Set-Location '$root'; .\mvnw.cmd -pl eureka-server spring-boot:run"
)

Start-Sleep -Seconds 8
Write-Host "Eureka iniciado. Agora rode: .\start-backends.ps1"
