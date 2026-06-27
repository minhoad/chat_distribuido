# Testes de Disponibilidade (Chaos / Resiliência)

Scripts para avaliar comportamento do sistema sob falhas — complementam os testes unitários/integração Maven.

## Pré-requisitos

```powershell
docker compose up -d          # infra UP (postgres, mongo, redis, kafka)
.\start-eureka.ps1
.\start-backends.ps1
```

## Testes automatizados existentes (Maven)

```powershell
$env:JAVA_HOME = "D:\java"
.\mvnw.cmd test
```

9 testes (auth + history). Auth usa H2 em memória no profile `test` — **não precisa de Docker**.

## Scripts de caos

**Nota:** os scripts usam apenas ASCII nas strings PowerShell (sem em-dash `—`) para evitar erros de encoding no Windows.

| Script | Simula | O que observar |
|--------|--------|----------------|
| `check_health.ps1` | - | Docker + portas + HTTP auth/gateway |
| `scenario_01_network_postgres.ps1` | **Tirar rede/DB** (stop postgres) | auth falha; após restore **reiniciar auth-service** |
| `scenario_02_network_redis.ps1` | Redis indisponível | auth OK; chat tempo real degradado |
| `scenario_03_latency_pause.ps1` | **Atraso/tráfego interrompido** (`docker pause` Kafka) | persistência atrasada |
| `scenario_04_memory_pressure.ps1` | **Pressão memória** (`docker update --memory`) | OOM ou degradação |
| `run_all_chaos.ps1` | Todos acima | - |

```powershell
cd chaos-test
.\check_health.ps1
.\scenario_01_network_postgres.ps1
# ou
.\run_all_chaos.ps1
```

## Firebase Test Lab

**Não se aplica** a este backend Java/Spring. Firebase Test Lab executa testes instrumentados em **apps Android/iOS** (incluindo robo tests, memory leaks).

Para microsserviços, equivalentes honestos:

- **Memória:** `scenario_04_memory_pressure.ps1` (limite Docker)
- **Rede:** `docker stop` / `docker network disconnect`
- **Latência:** `docker pause` ou [Toxiproxy](https://github.com/Shopify/toxiproxy)

## Causa comum: Connection refused :5432

O container `chat-postgres` estava **parado** (`Exited`). Correção:

```powershell
docker compose up -d postgres
docker compose ps postgres   # deve estar "healthy"
# Reinicie auth-service (janela Maven ou start-backends.ps1)
```

Todos os serviços Docker agora têm `restart: unless-stopped` para subir após reboot do Docker Desktop.
