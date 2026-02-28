# xshopai — Local Development Setup

Run the entire xshopai platform on your local machine with a single command.
All services communicate via HTTP (no Dapr).

> **Looking for Codespace setup?** See [../.devcontainer/](../.devcontainer/) — one-click cloud-based dev environment.
>
> **Need Dapr-based local dev?** A `local-dapr/` folder will be added in the future.

---

## Prerequisites

| Tool             | Version | Install                                                          |
| ---------------- | ------- | ---------------------------------------------------------------- |
| **Docker**       | 24+     | [docker.com](https://docs.docker.com/get-docker/)               |
| **Node.js**      | 18+     | [nodejs.org](https://nodejs.org/)                                |
| **Python**       | 3.12+   | [python.org](https://www.python.org/downloads/)                  |
| **Java**         | 17+     | [adoptium.net](https://adoptium.net/)                            |
| **.NET SDK**     | 8+      | [dotnet.microsoft.com](https://dotnet.microsoft.com/download)    |
| **Git**          | 2.30+   | [git-scm.com](https://git-scm.com/)                             |

---

## Quick Start (One Command)

```bash
cd dev/local
./setup.sh --seed
```

This will:

1. ✅ Check all prerequisites are installed
2. ✅ Clone all 16 service repositories + db-seeder
3. ✅ Start all infrastructure (12 Docker containers)
4. ✅ Seed `.env` / config files for every service
5. ✅ Build all services (Node.js, Python, .NET, Java)
6. ✅ Seed databases with sample data

Then start the platform:

```bash
./dev.sh
```

---

## Setup Options

```bash
./setup.sh                 # Full setup (no DB seeding)
./setup.sh --seed          # Full setup + seed databases
./setup.sh --skip-build    # Skip the build step (useful for reruns)
./setup.sh --infra-only    # Only start Docker infrastructure
```

---

## Running Services

```bash
./dev.sh              # Start all 14 backend services + 2 UIs
./dev.sh --stop       # Stop all running services
```

Logs are written to `dev/logs/<service-name>.log`.

```bash
tail -f ../logs/web-bff.log          # Watch a specific service
tail -f ../logs/product-service.log
```

---

## Building Services

```bash
./build.sh --all                           # Build everything (parallel)
./build.sh --all --sequential              # Build everything (sequential)
./build.sh user-service                    # Build a single service
./build.sh user-service auth-service       # Build multiple services
./build.sh --all --clean                   # Clean + rebuild
./build.sh --all --test                    # Build + run tests
./build.sh --clean-only                    # Just clean build artifacts
```

---

## Service Endpoints

### Frontend Applications

| Service     | URL                   |
| ----------- | --------------------- |
| Customer UI | http://localhost:3000  |
| Admin UI    | http://localhost:3001  |

### Backend for Frontend

| Service | URL                   |
| ------- | --------------------- |
| Web BFF | http://localhost:8014  |

### Microservices

| Service              | Port | URL                   |
| -------------------- | ---- | --------------------- |
| Product Service      | 8001 | http://localhost:8001 |
| User Service         | 8002 | http://localhost:8002 |
| Admin Service        | 8003 | http://localhost:8003 |
| Auth Service         | 8004 | http://localhost:8004 |
| Inventory Service    | 8005 | http://localhost:8005 |
| Order Service        | 8006 | http://localhost:8006 |
| Order Processor      | 8007 | http://localhost:8007 |
| Cart Service         | 8008 | http://localhost:8008 |
| Payment Service      | 8009 | http://localhost:8009 |
| Review Service       | 8010 | http://localhost:8010 |
| Notification Service | 8011 | http://localhost:8011 |
| Audit Service        | 8012 | http://localhost:8012 |
| Chat Service         | 8013 | http://localhost:8013 |

### Infrastructure UIs

| Service             | URL                    | Credentials        |
| ------------------- | ---------------------- | ------------------ |
| RabbitMQ Management | http://localhost:15672  | admin / admin123   |
| Zipkin Tracing      | http://localhost:9411   | —                  |
| Mailpit Email UI    | http://localhost:8025   | —                  |

### Database Connections

| Database           | Port  | Connection String                                                              |
| ------------------ | ----- | ------------------------------------------------------------------------------ |
| User MongoDB       | 27018 | `mongodb://admin:admin123@localhost:27018/user_service_db?authSource=admin`     |
| Product MongoDB    | 27019 | `mongodb://admin:admin123@localhost:27019/product_service_db?authSource=admin`  |
| Review MongoDB     | 27020 | `mongodb://admin:admin123@localhost:27020/review_service_db?authSource=admin`   |
| Audit PostgreSQL   | 5434  | `postgresql://admin:admin123@localhost:5434/audit_service_db`                   |
| Order Processor PG | 5435  | `postgresql://postgres:postgres@localhost:5435/order_processor_db`              |
| Order SQL Server   | 1434  | `Server=localhost,1434;User=sa;Password=Admin123!`                             |
| Payment SQL Server | 1433  | `Server=localhost,1433;User=sa;Password=Admin123!`                             |
| Inventory MySQL    | 3306  | `mysql://admin:admin123@localhost:3306/inventory_service_db`                    |
| Redis (Cart)       | 6379  | `redis://localhost:6379` (password: `redis_dev_pass_123`)                      |

---

## Managing Infrastructure

```bash
# From the dev/ root:
docker compose up -d              # Start all infrastructure
docker compose ps                 # Check status
docker compose logs -f rabbitmq   # View specific logs
docker compose restart user-mongodb
docker compose down               # Stop (keep data)
docker compose down --volumes     # Stop + delete all data ⚠️
```

---

## Troubleshooting

### Port Already in Use

```bash
# Find what's using a port
lsof -i :8001       # macOS/Linux
netstat -ano | findstr :8001   # Windows
```

### Database Not Ready

SQL Server and MySQL can take 30–60 seconds to initialize on first start. Re-run `./setup.sh --skip-build` to recheck.

### Build Failures

```bash
# Rebuild a single service with clean
./build.sh user-service --clean

# Check the build log
cat ../logs/build.log
```

### Reset Everything

```bash
# Stop services
./dev.sh --stop

# Tear down infrastructure + data
docker compose -f ../docker-compose.yml down --volumes

# Re-run setup
./setup.sh --seed
```

---

## Folder Structure

```
dev/
├── local/                  ← You are here (HTTP-based local dev)
│   ├── setup.sh            ← One-command setup orchestrator
│   ├── dev.sh              ← Start/stop all services
│   ├── build.sh            ← Build services (all or individual)
│   └── README.md           ← This file
├── .devcontainer/          ← Codespace / devcontainer setup
│   ├── devcontainer.json
│   ├── setup.sh
│   └── scripts/
├── docker-compose.yml      ← Shared infrastructure (12 containers)
├── .env.example            ← Environment variable reference
├── xshopai.code-workspace  ← VS Code multi-root workspace
└── logs/                   ← Service log files (gitignored)
```

---

**⚠️ Security Note:** All credentials in this setup are for local development only. Never use these in production!
