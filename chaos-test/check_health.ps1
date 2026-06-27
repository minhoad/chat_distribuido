# Verifica infra Docker + endpoints HTTP dos microsservicos.
param(
    [string]$Gateway = "http://localhost:8080",
    [string]$Auth = "http://localhost:8081",
    [string]$Eureka = "http://localhost:8761"
)

$ErrorActionPreference = "Continue"
$results = @()

function Test-TcpPort {
    param([string]$HostName, [int]$Port)
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $async = $client.BeginConnect($HostName, $Port, $null, $null)
        $ok = $async.AsyncWaitHandle.WaitOne(2000, $false)
        if ($ok -and $client.Connected) { $client.Close(); return $true }
        $client.Close()
        return $false
    } catch { return $false }
}

function Test-Http {
    param([string]$Url, [int]$TimeoutSec = 5)
    try {
        $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $TimeoutSec
        return @{ Ok = $true; Status = [string]$r.StatusCode }
    } catch {
        $status = $null
        if ($_.Exception.Response) { $status = [string][int]$_.Exception.Response.StatusCode }
        return @{ Ok = $false; Status = $status; Error = $_.Exception.Message }
    }
}

function Add-CheckResult {
    param([string]$Name, [bool]$Ok, [string]$Detail = "")
    $script:results += [PSCustomObject]@{
        Check = $Name
        Ok = $Ok
        Detail = $Detail
    }
}

$containers = @("chat-postgres", "chat-mongodb", "chat-redis", "chat-kafka")
foreach ($c in $containers) {
    $state = docker inspect -f "{{.State.Status}}" $c 2>$null
    Add-CheckResult -Name "docker:$c" -Ok ($state -eq "running") -Detail ([string]$state)
}

$ports = @(
    @{ Name = "tcp:5432 postgres"; Port = 5432 },
    @{ Name = "tcp:6379 redis"; Port = 6379 },
    @{ Name = "tcp:27017 mongo"; Port = 27017 },
    @{ Name = "tcp:9094 kafka"; Port = 9094 },
    @{ Name = "tcp:8761 eureka"; Port = 8761 },
    @{ Name = "tcp:8080 gateway"; Port = 8080 },
    @{ Name = "tcp:8081 auth"; Port = 8081 }
)
foreach ($p in $ports) {
    Add-CheckResult -Name $p.Name -Ok (Test-TcpPort "localhost" $p.Port)
}

$eurekaHttp = Test-Http "$Eureka/"
Add-CheckResult -Name "http:eureka" -Ok ([bool]$eurekaHttp.Ok) -Detail ([string]$eurekaHttp.Status)

$authUsers = Test-Http "$Auth/api/auth/users"
Add-CheckResult -Name "http:auth/users" -Ok ([bool]$authUsers.Ok) -Detail ([string]$authUsers.Status)

$gwUsers = Test-Http "$Gateway/api/auth/users"
Add-CheckResult -Name "http:gateway/auth/users" -Ok ([bool]$gwUsers.Ok) -Detail ([string]$gwUsers.Status)

$results | Format-Table -AutoSize
$failed = @($results | Where-Object { -not $_.Ok }).Count
if ($failed -eq 0) {
    Write-Host "OK: todos os checks passaram."
    exit 0
}
Write-Host "FALHA: $failed check(s) com problema."
exit 1
