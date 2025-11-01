# NomadForms Database

PostgreSQL database schema and migrations for NomadForms.

## Quick Setup

### Option 1: Local PostgreSQL

```bash
# Install PostgreSQL (Ubuntu/Debian)
sudo apt-get install postgresql postgresql-contrib

# Create database
sudo -u postgres createdb nomadforms

# Run migrations
psql -U postgres -d nomadforms -f migrations/001_initial_schema.sql
```

### Option 2: Supabase (Recommended)

1. Create account at [supabase.com](https://supabase.com)
2. Create new project
3. Go to SQL Editor
4. Run the migration script from `migrations/001_initial_schema.sql`
5. Get connection string from Settings > Database

### Option 3: Docker

```bash
# Start PostgreSQL in Docker
docker run --name nomadforms-db \
  -e POSTGRES_PASSWORD=nomadforms \
  -e POSTGRES_DB=nomadforms \
  -p 5432:5432 \
  -d postgres:15

# Run migrations
docker exec -i nomadforms-db psql -U postgres -d nomadforms < migrations/001_initial_schema.sql
```

## Schema Overview

### Tables

- **projects**: Survey definitions and configurations
- **responses**: Individual survey responses
- **audit_log**: Complete audit trail of all operations
- **users**: User accounts (for multi-user deployments)
- **sync_queue**: Offline synchronization queue

### Key Features

- UUID primary keys
- Automatic timestamps (created_at, updated_at)
- JSONB for flexible metadata storage
- Comprehensive indexing for performance
- Row-level security ready (Supabase)

## Migrations

Migrations are numbered sequentially:
- `001_initial_schema.sql` - Initial database setup

## Connection from R

```r
library(nomadforms)

# Local PostgreSQL
conn <- nf_database(
  dbname = "nomadforms",
  user = "postgres",
  password = "your_password"
)

# Supabase
conn <- nf_database(
  connection_string = Sys.getenv("DATABASE_URL")
)

# Initialize schema (if not done via SQL)
nf_init_schema(conn)
```

## Environment Variables

Add to `.env` file (never commit this!):

```
DATABASE_URL=postgresql://user:password@host:5432/nomadforms
```

## Backup

```bash
# Backup
pg_dump -U postgres nomadforms > backup.sql

# Restore
psql -U postgres nomadforms < backup.sql
```

## Security

- Never commit database credentials
- Use environment variables for connection strings
- Enable SSL/TLS for remote connections
- Set up row-level security policies (Supabase)
- Regular backups recommended

