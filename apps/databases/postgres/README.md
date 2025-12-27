# PostgreSQL Database

Powerful open-source relational database with ACID compliance.

## Features
- ACID compliant transactions
- Advanced SQL support
- JSON/JSONB support
- Full-text search
- Replication support

## Installation
Automatically configures:
- PostgreSQL 16 (Alpine Linux)
- Auto-generated secure credentials
- Docker volume for data persistence
- Health checks
- Connected to vps_network

## Credentials
Stored securely in: `~/.vps-secrets/.env_postgres`

## Connection

### From Docker Network (recommended)
```bash
# Connection string
postgresql://postgres:[PASSWORD]@postgres:5432/postgres

# Using psql inside container
docker exec -it postgres psql -U postgres
```

### External Connection
```bash
# Enable external access (if needed)
# Firewall is not opened by default for security

# Connection string
postgresql://postgres:[PASSWORD]@SERVER_IP:5432/postgres
```

## Management

### Common Commands
```bash
# View logs
docker logs postgres

# Connect to database
docker exec -it postgres psql -U postgres

# Backup database
docker exec postgres pg_dump -U postgres postgres > backup.sql

# Restore database
docker exec -i postgres psql -U postgres < backup.sql

# Check status
docker ps | grep postgres

# Restart container
docker restart postgres
```

### Database Operations
```sql
-- Create database
CREATE DATABASE myapp;

-- Create user
CREATE USER myuser WITH ENCRYPTED PASSWORD 'password';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE myapp TO myuser;

-- List databases
\l

-- Connect to database
\c myapp

-- List tables
\dt
```

## Data Location
- Data directory: `/opt/databases/postgres/data`
- Volume: Docker managed
- Backup recommended before major changes

## Performance Tuning
Edit PostgreSQL configuration:
```bash
docker exec -it postgres vi /var/lib/postgresql/data/postgresql.conf
```

Common settings:
```
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
max_connections = 100
```

## Security
- Credentials auto-generated and stored securely
- Not exposed externally by default
- Use Docker network for inter-container communication
- Enable SSL for production external access

## Troubleshooting
```bash
# Check logs
docker logs postgres --tail 100

# Check health
docker inspect postgres | grep -A 10 Health

# Test connection
docker exec postgres pg_isready -U postgres
```
