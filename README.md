# xshopai — Development Environment

This repository contains everything needed to run the xshopai platform for development. Choose one of the setup options below.

---

## Option 1: GitHub Codespace (Recommended)

One-click cloud-based development environment. Everything is pre-configured — infrastructure, services, and tooling.

**Get started:**

1. Go to [github.com/xshopai/dev](https://github.com/xshopai/dev)
2. Click **Code → Codespaces → Create codespace on main**
3. Select a machine with ≥ 8 cores / 32 GB RAM
4. Wait for setup to complete (~5 minutes)
5. Run all services: `.devcontainer/dev.sh`

📖 See [.devcontainer/](.devcontainer/) for details.

---

## Option 2: Local Development

Run the platform on your own machine. Requires Docker, Node.js, Python, Java, and .NET SDK.

**Get started:**

```bash
git clone https://github.com/xshopai/dev.git
cd dev/local
./setup.sh --seed    # Clone repos, start infra, build, seed DBs
./dev.sh             # Start all 16 services
```

📖 See [local/README.md](local/README.md) for full instructions, prerequisites, and troubleshooting.

---

## Option 3: Local with Dapr (Coming Soon)

Run the platform locally with Dapr sidecars for service invocation, pub/sub, and state management.

> A `local-dapr/` folder will be added in a future update.

---

## Repository Structure

```
dev/
├── .devcontainer/          Codespace / devcontainer setup
│   ├── devcontainer.json   Container configuration
│   ├── setup.sh            Automated setup orchestrator
│   ├── dev.sh              Start/stop all services (Codespace)
│   └── scripts/            Setup phases (clone, build, env, infra, seed)
│
├── local/                  Local development setup (HTTP, no Dapr)
│   ├── setup.sh            One-command local setup
│   ├── dev.sh              Start/stop all services (local)
│   ├── build.sh            Build individual or all services
│   └── README.md           Full local setup guide
│
├── docker-compose.yml      Infrastructure services (12 containers)
│                           Shared by both Codespace and local setups
│
├── .env.example            Environment variable reference
├── xshopai.code-workspace  VS Code multi-root workspace file
└── logs/                   Service log files (gitignored)
```

## Infrastructure Services

Started by `docker-compose.yml` (shared between all setups):

| Service            | Container                    | Ports         |
| ------------------ | ---------------------------- | ------------- |
| RabbitMQ           | dev-rabbitmq                 | 5672, 15672   |
| Zipkin             | dev-zipkin                   | 9411          |
| Mailpit            | dev-mailpit                  | 1025, 8025    |
| Redis              | dev-redis                    | 6379          |
| User MongoDB       | dev-user-mongodb             | 27018 → 27017 |
| Product MongoDB    | dev-product-mongodb          | 27019 → 27017 |
| Review MongoDB     | dev-review-mongodb           | 27020 → 27017 |
| Audit PostgreSQL   | dev-audit-postgres           | 5434 → 5432   |
| Order Processor PG | dev-order-processor-postgres | 5435 → 5432   |
| Order SQL Server   | dev-order-sqlserver          | 1434 → 1433   |
| Payment SQL Server | dev-payment-sqlserver        | 1433 → 1433   |
| Inventory MySQL    | dev-inventory-mysql          | 3306 → 3306   |

## Application Services

| Service              | Tech       | Port |
| -------------------- | ---------- | ---- |
| Product Service      | Python     | 8001 |
| User Service         | Node.js    | 8002 |
| Admin Service        | Node.js    | 8003 |
| Auth Service         | Node.js    | 8004 |
| Inventory Service    | Python     | 8005 |
| Order Service        | .NET 8     | 8006 |
| Order Processor      | Java 17    | 8007 |
| Cart Service         | TypeScript | 8008 |
| Payment Service      | .NET 8     | 8009 |
| Review Service       | Node.js    | 8010 |
| Notification Service | TypeScript | 8011 |
| Audit Service        | Node.js    | 8012 |
| Chat Service         | TypeScript | 8013 |
| Web BFF              | TypeScript | 8014 |
| Customer UI          | React      | 3000 |
| Admin UI             | React      | 3001 |

---

## License

See [LICENSE](LICENSE).
