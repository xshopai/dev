# xshopai - Local Development Setup

Complete guide for setting up and running xshopai locally for development.

## 🚀 Quick Start

### Prerequisites

- **Docker Desktop** (Windows/Mac) or **Docker Engine** (Linux)
- **Node.js 18+** (for TypeScript/JavaScript services)
- **Python 3.12+** (for Python services)
- **Java 17+** (for Java services)
- **.NET 8 SDK** (for C# services)
- **Dapr CLI** (for running services with Dapr)

### One-Command Setup

```bash
cd dev
./setup.sh --seed
```

This will:

1. ✅ Start all infrastructure (databases, RabbitMQ, Zipkin, Mailpit)
2. ✅ Wait for services to be healthy
3. ✅ Seed initial data

Then start the application services:

```bash
cd ../scripts
./dev.sh    # Starts all services with Dapr
```

## 📋 Manual Setup (Step by Step)

### Step 1: Start Infrastructure

```bash
cd dev
docker-compose up -d
```

**What this starts:**

- RabbitMQ (message broker)
- Zipkin (distributed tracing)
- Mailpit (email testing)
- Redis (cache & session store for cart service)
- MongoDB (3 instances: user, product, review)
- PostgreSQL (2 instances: audit, order-processor)
- SQL Server (2 instances: order, payment)
- MySQL (1 instance: inventory)

> **Note:** Auth service uses user-service database via API calls (no separate database)
> **Note:** Cart service uses Redis for cart data (no traditional database)

### Step 2: Verify Services Are Running

```bash
docker-compose ps
```

All services should be in "healthy" or "running" state.

### Step 3: Seed Data (Optional)

```bash
cd ../scripts
./seed.sh
```

### Step 4: Start Application Services

```bash
./dev.sh    # With Dapr (recommended)
# or
./local.sh  # Without Dapr (limited functionality)
```

## 🌐 Service Endpoints

### Infrastructure Services

| Service             | URL                    | Credentials        |
| ------------------- | ---------------------- | ------------------ |
| RabbitMQ Management | http://localhost:15672 | admin / admin123   |
| Zipkin Tracing      | http://localhost:9411  | -                  |
| Mailpit Email UI    | http://localhost:8025  | -                  |
| Redis (Cart Cache)  | localhost:6379         | redis_dev_pass_123 |

### Application Services

| Service              | Port | URL                   |
| -------------------- | ---- | --------------------- |
| Customer UI          | 3000 | http://localhost:3000 |
| Admin UI             | 3001 | http://localhost:3001 |
| Web BFF              | 8014 | http://localhost:8014 |
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

### Database Connections

| Database           | Port  | Connection String                                                              |
| ------------------ | ----- | ------------------------------------------------------------------------------ |
| User MongoDB       | 27018 | `mongodb://admin:admin123@localhost:27018/user_service_db?authSource=admin`    |
| Product MongoDB    | 27019 | `mongodb://admin:admin123@localhost:27019/product_service_db?authSource=admin` |
| Review MongoDB     | 27020 | `mongodb://admin:admin123@localhost:27020/review_service_db?authSource=admin`  |
| Audit PostgreSQL   | 5434  | `postgresql://admin:admin123@localhost:5434/audit_service_db`                  |
| Order Processor PG | 5435  | `postgresql://postgres:postgres@localhost:5435/order_processor_db`             |
| Order SQL Server   | 1434  | `Server=localhost,1434;User=sa;Password=Admin123!`                             |
| Payment SQL Server | 1433  | `Server=localhost,1433;User=sa;Password=Admin123!`                             |
| Inventory MySQL    | 3306  | `mysql://admin:admin123@localhost:3306/inventory_service_db`                   |

## 🛠️ Common Tasks

### View Infrastructure Logs

```bash
cd dev
docker-compose logs -f          # All services
docker-compose logs -f rabbitmq # Specific service
```

### Restart a Database

```bash
docker-compose restart user-mongodb
```

### Stop Infrastructure

```bash
docker-compose down              # Keep data
docker-compose down --volumes    # Remove all data! ⚠️
```

### Clean Start (Remove All Data)

```bash
./setup.sh --clean
```

### Connect to a Database

**MongoDB:**

```bash
mongosh mongodb://admin:admin123@localhost:27018/user_service_db?authSource=admin
```

**PostgreSQL:**

```bash
psql postgresql://admin:admin123@localhost:5434/audit_service_db
```

**SQL Server:**

```bash
sqlcmd -S localhost,1434 -U sa -P Admin123!
```

**MySQL:**

```bash
mysql -h localhost -P 3306 -u admin -padmin123 inventory_service_db
```

## 🐛 Troubleshooting

### Port Already in Use

**Problem:** "port is already allocated"

**Solution:**

```bash
# Check what's using the port (example: 5672)
# Windows
netstat -ano | findstr :5672

# Mac/Linux
lsof -i :5672

# Kill the process or change port in docker-compose.yml
```

### Container Won't Start

**Problem:** Container exits immediately

**Solution:**

```bash
# View detailed logs
docker-compose logs <service-name>

# Remove container and try again
docker-compose down
docker-compose up -d
```

### Database Connection Refused

**Problem:** Service can't connect to database

**Solution:**

1. Check database is running: `docker-compose ps`
2. Verify connection string in service `.env` file
3. Wait longer for database initialization (30-60 seconds for SQL Server)
4. Check firewall/antivirus isn't blocking ports

### Out of Disk Space

**Problem:** "no space left on device"

**Solution:**

```bash
# Remove unused Docker data
docker system prune -a --volumes

# Check disk usage
docker system df
```

## 🔄 Development Workflow

### Typical Day

```bash
# Morning: Start infrastructure
cd dev
./setup.sh

# Start services you're working on
cd ../scripts
./dev.sh

# Work on your feature...

# Evening: Stop everything
cd dev
docker-compose down
```

### Working on a Single Service

```bash
# Start infrastructure
cd dev
./setup.sh

# Run only the services you need
cd ../<service-name>
./scripts/dapr.sh   # or ./scripts/local.sh
```

### Testing Event Flows

```bash
# Ensure infrastructure is running
cd dev
docker-compose ps

# Check RabbitMQ for messages
# Open http://localhost:15672
# Login with admin/admin123
# Go to Queues tab

# Check Zipkin for traces
# Open http://localhost:9411
```

## 📝 Environment Variables

Copy `.env.example` to `.env` and customize:

```bash
cp .env.example .env
# Edit .env with your settings
```

All services will use these connection strings automatically when running locally.

## 🔒 Security Notes

⚠️ **FOR LOCAL DEVELOPMENT ONLY**

- Default credentials are weak (admin/admin123)
- Databases accept connections from any host (0.0.0.0)
- No TLS/SSL encryption
- JWT secret is shared and simple

**Never use these configurations in production!**

## 📚 Additional Resources

- **Main README**: `../README.md`
- **Deployment Guide**: `../deployment/README.md`
- **Service Documentation**: Each service has its own README
- **Architecture Docs**: `../docs/`

## 🆘 Getting Help

If you encounter issues:

1. Check this README's Troubleshooting section
2. Search existing GitHub issues
3. Ask in team chat
4. Create a new GitHub issue with:
   - Error message
   - Steps to reproduce
   - Output of `docker-compose ps`
   - Output of `docker-compose logs <service>`

---

**Happy coding! 🚀**
