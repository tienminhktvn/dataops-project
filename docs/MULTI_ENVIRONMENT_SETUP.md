# 🌍 Multi-Environment Setup Guide

> **Comprehensive guide for managing development, CI, and production environments**

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Environment Architecture](#environment-architecture)
3. [Development Environment](#development-environment)
4. [CI Environment](#ci-environment)
5. [Production Environment](#production-environment)
6. [Environment Configuration](#environment-configuration)
7. [Environment Promotion](#environment-promotion)
8. [Configuration Management](#configuration-management)

---

## Overview

### Environment Strategy

The DataOps project implements a **three-tier environment strategy**:

| Environment           | Purpose                       | Infrastructure        | Data                     | Automation |
| --------------------- | ----------------------------- | --------------------- | ------------------------ | ---------- |
| **Development (dev)** | Local development and testing | Local Docker          | Sample/Test data         | Manual     |
| **CI (ci)**           | Automated testing in PRs      | GitHub-hosted runners | Ephemeral container data | Automatic  |
| **Production (prod)** | Production deployment         | Self-hosted runner    | Production data          | Automatic  |

### Environment Isolation

```
┌─────────────────────────────────────────────────────────────┐
│                    SOURCE CODE (GitHub)                     │
└─────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┼─────────────┐
                │             │             │
                ▼             ▼             ▼
         ┌──────────┐   ┌──────────┐   ┌──────────┐
         │   DEV    │   │    CI    │   │   PROD   │
         │  Local   │   │  GitHub  │   │Self-Host │
         └──────────┘   └──────────┘   └──────────┘
              │              │              │
              ▼              ▼              ▼
         Docker Comp    Temp Cont.    Docker Comp
         Persistent     Ephemeral     Persistent
         Volumes        Volumes       Volumes
```

---

## Environment Architecture

### Development Environment

**Purpose**: Local development, testing, and debugging

**Infrastructure**:

- Local machine (Windows/Mac/Linux)
- Docker Desktop
- Docker Compose orchestration

**Characteristics**:

- ✅ Full control over environment
- ✅ Persistent data volumes
- ✅ Interactive debugging
- ✅ UI access (Airflow, CloudBeaver)
- ⚠️ Manual deployment
- ⚠️ Single developer

**Lifecycle**: Long-lived (days to weeks)

---

### CI Environment

**Purpose**: Automated testing for Pull Requests

**Infrastructure**:

- GitHub-hosted runners (ubuntu-latest)
- Ephemeral containers
- Temporary volumes

**Characteristics**:

- ✅ Isolated per PR
- ✅ Automated creation/teardown
- ✅ Consistent environment
- ✅ Fast feedback (<5 minutes)
- ⚠️ No UI access
- ⚠️ Limited resources (7GB RAM, 14GB disk)

**Lifecycle**: Short-lived (minutes)

---

### Production Environment

**Purpose**: Production deployment and operation

**Infrastructure**:

- Self-hosted GitHub Actions runner (Ubuntu 20.04)
- Docker Compose orchestration
- Persistent volumes

**Characteristics**:

- ✅ Automated deployment
- ✅ Persistent data
- ✅ High availability
- ✅ Monitoring and alerts
- ⚠️ Restricted access
- ⚠️ Change control required

**Lifecycle**: Long-lived (indefinite)

---

## Development Environment

### Setup

**Prerequisites**:

- Docker Desktop installed
- Git installed
- 8GB RAM available
- 10GB disk space

**Installation Steps**:

```powershell
# 1. Clone repository
git clone https://github.com/tienminhktvn/dataops-project.git
cd dataops-project

# 2. Checkout develop branch
git checkout develop

# 3. Create environment file (optional)
echo "SLACK_WEBHOOK_URL=your_webhook_url" > .env

# 4. Start infrastructure
docker-compose up -d --build

# 5. Wait for services to be ready
Start-Sleep -Seconds 60

# 6. Restore database
docker exec dataops-sqlserver /bin/bash /tmp/restore_db.sh

# 7. Run DBT models
docker exec dataops-dbt dbt deps --profiles-dir .
docker exec dataops-dbt dbt run --target dev --profiles-dir .

# 8. Verify deployment
docker ps
docker exec dataops-dbt dbt test --target dev --profiles-dir .
```

### Configuration

**DBT Target: `dev`**

Location: `dbt/profiles.yml`

```yaml
dev:
  type: sqlserver
  driver: ODBC Driver 17 for SQL Server
  server: dataops-sqlserver
  port: 1433
  database: AdventureWorks2014
  schema: dbo
  user: sa
  password: YourPassword123!
  threads: 4
  trust_cert: true
```

**Airflow Configuration**:

Location: `docker-compose.yml`

```yaml
environment:
  AIRFLOW__CORE__EXECUTOR: LocalExecutor
  AIRFLOW__CORE__SQL_ALCHEMY_CONN: postgresql+psycopg2://airflow:airflow@dataops-postgres/airflow
  AIRFLOW__CORE__LOAD_EXAMPLES: "false"
  AIRFLOW__WEBSERVER__EXPOSE_CONFIG: "true"
```

### Access Points

| Service        | URL                   | Credentials                   |
| -------------- | --------------------- | ----------------------------- |
| Airflow Web UI | http://localhost:8080 | admin / admin                 |
| CloudBeaver    | http://localhost:8978 | Setup on first access         |
| SQL Server     | localhost:1433        | sa / YourPassword123!         |
| Postgres       | localhost:5432        | airflow / airflow             |
| DBT Docs       | http://localhost:8001 | None (after `dbt docs serve`) |

### Development Workflow

```
1. Create Feature Branch
   git checkout -b feature/my-feature
         │
         ▼
2. Modify Code (DBT models, Airflow DAGs)
   Edit files in dbt/models/ or airflow/dags/
         │
         ▼
3. Test Locally
   docker exec dataops-dbt dbt run --select my_model --target dev
   docker exec dataops-dbt dbt test --select my_model --target dev
         │
         ▼
4. Verify in UI
   - Check Airflow DAG execution
   - Query data in CloudBeaver
   - Review DBT documentation
         │
         ▼
5. Commit & Push
   git add .
   git commit -m "feat: add my feature"
   git push origin feature/my-feature
         │
         ▼
6. Create Pull Request
   GitHub UI -> New Pull Request
         │
         ▼
7. CI Tests Run Automatically
   Wait for GitHub Actions to pass
         │
         ▼
8. Merge to develop
   Triggers automatic deployment to dev environment
```

### Debugging Tips

**View Logs**:

```powershell
# Airflow scheduler
docker logs -f dataops-airflow-scheduler

# DBT container
docker logs -f dataops-dbt

# SQL Server
docker logs -f dataops-sqlserver
```

**Interactive Shell**:

```powershell
# Access DBT container
docker exec -it dataops-dbt bash

# Access Airflow scheduler
docker exec -it dataops-airflow-scheduler bash

# Access SQL Server
docker exec -it dataops-sqlserver bash
```

**Test Individual Models**:

```powershell
# Run one model
docker exec dataops-dbt dbt run --select brnz_sales_orders --target dev --profiles-dir .

# Run with dependencies
docker exec dataops-dbt dbt run --select +slvr_sales_orders --target dev --profiles-dir .

# Run downstream models
docker exec dataops-dbt dbt run --select slvr_sales_orders+ --target dev --profiles-dir .
```

---

## CI Environment

### Setup

**Automatic Setup**: CI environment is created automatically by GitHub Actions when:

- Pull Request is opened
- New commits are pushed to an open PR

**Workflow**: `.github/workflows/ci-dbt-test.yml`

### Configuration

**DBT Target: `ci`**

Location: `dbt/profiles.yml`

```yaml
ci:
  type: sqlserver
  driver: ODBC Driver 17 for SQL Server
  server: localhost
  port: 1433
  database: AdventureWorks2014
  schema: dbo
  user: sa
  password: YourPassword123!
  threads: 2
  trust_cert: true
```

**Key Differences from Dev**:

- `server: localhost` (ephemeral container, not Docker network name)
- `threads: 2` (lower resource usage for CI runner)

### CI Pipeline Steps

```
1. Checkout Code
   ↓
2. Start SQL Server Container
   docker run -d -p 1433:1433 mcr.microsoft.com/mssql/server:2019-latest
   ↓
3. Restore AdventureWorks Database
   Wait 60s → Restore .bak file → Verify
   ↓
4. Build DBT Image
   docker build -t dbt-ci ./dbt
   ↓
5. Install DBT Dependencies
   docker run dbt-ci dbt deps
   ↓
6. Parse DBT Models
   docker run dbt-ci dbt parse --target ci
   ↓
7. Run DBT Models
   docker run dbt-ci dbt run --target ci
   ↓
8. Run DBT Tests
   docker run dbt-ci dbt test --target ci
   ↓
9. Generate Test Report
   Parse results → Comment on PR
```

### CI Constraints

**Runner Limitations**:

- 7GB RAM
- 14GB disk space
- 2 CPU cores
- No persistent storage

**Optimizations for CI**:

```yaml
# Reduced threads
threads: 2

# Faster materialization
models:
  bronze:
    +materialized: view # Instead of table
```

**Caching Strategy**:

```yaml
# Cache DBT packages
- uses: actions/cache@v3
  with:
    path: dbt/dbt_packages
    key: ${{ runner.os }}-dbt-${{ hashFiles('dbt/packages.yml') }}
```

### CI Testing Strategy

**Test Levels**:

1. ✅ **Parse**: Validate SQL syntax
2. ✅ **Run**: Build all models
3. ✅ **Test**: Execute data quality tests
4. ✅ **Lint**: Check code style (separate workflow)

**Coverage Requirements**:

- All models must parse successfully
- All models must build without errors
- All data quality tests must pass

### Troubleshooting CI Failures

**Common Issues**:

**SQL Syntax Error**:

```yaml
Error: compilation error in model brnz_sales_orders
  Syntax error near 'FROM'

Solution: Fix SQL syntax in model file
```

**Connection Timeout**:

```yaml
Error: Cannot connect to SQL Server at localhost:1433

Solution: Increase wait time before DBT runs
  - sleep 60 # Wait for SQL Server to be ready
```

**Out of Disk Space**:

```yaml
Error: No space left on device

Solution: Clean up Docker images in CI
  - docker system prune -f
```

---

## Production Environment

### Setup

**Infrastructure**: Self-hosted GitHub Actions runner on Ubuntu 20.04

**Prerequisites**:

- Ubuntu server with Docker installed
- GitHub Actions runner registered
- Network access to GitHub
- Sufficient resources (4GB RAM, 20GB disk)

**Setup Steps**: See [SELF_HOSTED_RUNNER_SETUP.md](SELF_HOSTED_RUNNER_SETUP.md)

### Configuration

**DBT Target: `prod`**

Location: `dbt/profiles.yml`

```yaml
prod:
  type: sqlserver
  driver: ODBC Driver 17 for SQL Server
  server: dataops-sqlserver
  port: 1433
  database: AdventureWorks2014
  schema: dbo
  user: sa
  password: YourPassword123!
  threads: 8
  trust_cert: true
```

**Key Differences from Dev**:

- `threads: 8` (higher concurrency for production)
- Same configuration otherwise (uses Docker network)

**Airflow Configuration** (Production):

```yaml
environment:
  AIRFLOW__CORE__EXECUTOR: LocalExecutor
  AIRFLOW__CORE__SQL_ALCHEMY_CONN: postgresql+psycopg2://airflow:airflow@dataops-postgres/airflow
  AIRFLOW__CORE__LOAD_EXAMPLES: "false"
  AIRFLOW__SCHEDULER__CATCHUP_BY_DEFAULT: "false"
  AIRFLOW__WEBSERVER__EXPOSE_CONFIG: "false" # Security: Hide config in prod
```

### Deployment Pipeline

**Trigger**: Push to `main` branch

**Workflow**: `.github/workflows/cd-deploy.yml`

```
1. Determine Environment
   Resolve to 'prod' based on branch
   ↓
2. Create Backup
   Generate backup metadata with commit SHA
   ↓
3. Checkout Code
   Pull latest code from main branch
   ↓
4. Stop Containers
   docker-compose down
   ↓
5. Fix Permissions
   chmod -R 777 airflow directories
   ↓
6. Rebuild & Restart
   docker-compose up -d --build
   ↓
7. Wait for Health
   Sleep 60 seconds
   ↓
8. Restore Database
   Ensure AdventureWorks is available
   ↓
9. Run DBT
   deps → run --target prod → test --target prod
   ↓
10. Validate
    Check Airflow DAG is registered
   ↓
11. Notify
    Send Slack notification (success/failure)
```

### Production Access

**Restricted Access**:

- Only via CI/CD pipelines
- No direct SSH access for developers
- Logs available in GitHub Actions
- UI access only for admins

**Monitoring**:

- Slack notifications for deployment status
- GitHub Actions logs for detailed information
- Airflow UI for DAG execution monitoring

### Production Safety Measures

**Pre-Deployment Checks**:

1. ✅ All CI tests must pass
2. ✅ Code review approved
3. ✅ Merged to main branch
4. ✅ No concurrent deployments (concurrency control)

**Backup Strategy**:

- Backup metadata created before each deployment
- Git tags for rollback points
- Database backups (if needed)

**Rollback Capability**:

- Automated rollback workflow available
- Can rollback to any previous commit
- Rollback time: ~3-5 minutes

---

## Environment Configuration

### Configuration Files

| File                      | Purpose                 | Environments         |
| ------------------------- | ----------------------- | -------------------- |
| `dbt/profiles.yml`        | DBT connection settings | All (dev, ci, prod)  |
| `docker-compose.yml`      | Container orchestration | Dev, Prod            |
| `.github/workflows/*.yml` | CI/CD pipelines         | CI, Prod             |
| `.env`                    | Environment variables   | Dev, Prod (optional) |
| `dbt/dbt_project.yml`     | DBT project config      | All                  |

### Environment Variables

**Development**:

```bash
# Optional .env file
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

**CI** (GitHub Secrets):

```yaml
# No secrets required (uses default passwords)
# SQL Server runs in ephemeral container
```

**Production** (GitHub Secrets):

```yaml
SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
# Injected into .env file during deployment
```

### Configuration Differences

| Setting                 | Dev               | CI        | Prod              |
| ----------------------- | ----------------- | --------- | ----------------- |
| **DBT Threads**         | 4                 | 2         | 8                 |
| **SQL Server Host**     | dataops-sqlserver | localhost | dataops-sqlserver |
| **Data Persistence**    | Yes               | No        | Yes               |
| **Airflow Examples**    | false             | N/A       | false             |
| **Expose Config**       | true              | N/A       | false             |
| **Slack Notifications** | Optional          | No        | Yes               |
| **Catchup**             | true              | N/A       | false             |

### DBT Variables

**Default Values** (`dbt_project.yml`):

```yaml
vars:
  start_date: "2011-05-31"
  end_date: "2014-06-30"
  high_value_threshold: 1000
  medium_value_threshold: 100
  top_performer_revenue: 50000
  medium_performer_revenue: 10000
```

**Override Per Environment**:

```powershell
# Development: Test with smaller date range
docker exec dataops-dbt dbt run --vars '{start_date: 2014-01-01, end_date: 2014-03-31}' --target dev --profiles-dir .

# Production: Use full date range (default)
docker exec dataops-dbt dbt run --target prod --profiles-dir .
```

---

## Environment Promotion

### Promotion Flow

```
Feature Branch
     │
     ├─ PR Created → CI Tests
     ↓
   develop
     │
     ├─ Push → Auto Deploy to Dev
     ↓
   main
     │
     └─ Push → Auto Deploy to Prod
```

### Promotion Checklist

**Develop → Main**:

1. ✅ **All CI tests pass**

   - DBT parse successful
   - All models build
   - All tests pass
   - Lint checks pass
   - PR validation pass

2. ✅ **Code review approved**

   - At least 1 approval
   - No unresolved comments

3. ✅ **Dev environment validated**

   - Manual testing completed
   - No runtime errors
   - Data quality verified

4. ✅ **Documentation updated**

   - README.md reflects changes
   - Model documentation current
   - Schema.yml updated

5. ✅ **Breaking changes documented**
   - Migration plan if needed
   - Backward compatibility verified

### Promotion Process

**Step 1: Prepare Main Branch**

```bash
# Ensure develop is up to date
git checkout develop
git pull origin develop

# Create release branch (optional)
git checkout -b release/v1.1.0
```

**Step 2: Create Pull Request**

```bash
# Push to GitHub
git push origin release/v1.1.0

# Create PR: release/v1.1.0 → main
# Title: "Release v1.1.0: Feature XYZ"
# Description: List of changes, testing notes
```

**Step 3: Review & Merge**

```bash
# Wait for CI checks to pass
# Obtain code review approval
# Merge to main (using "Squash and merge" or "Merge commit")
```

**Step 4: Monitor Deployment**

```bash
# Automatic deployment triggered
# Monitor GitHub Actions workflow
# Check Slack notification
# Verify in production Airflow UI
```

**Step 5: Validate Production**

```bash
# Check DBT models built successfully
# Verify data quality tests pass
# Monitor Airflow DAG execution
# Check data freshness
```

### Rollback Procedure

If production deployment fails or issues are discovered:

**Option 1: Automated Rollback**

```bash
# Via GitHub UI:
Actions → CD - Rollback Deployment → Run workflow
  Environment: prod
  Backup SHA: <previous_commit> or leave empty
  Reason: "Issue with feature XYZ"
```

**Option 2: Revert Commit**

```bash
# Revert the problematic commit on main
git checkout main
git pull
git revert <bad_commit_sha>
git push origin main

# Automatic deployment to prod triggered
```

---

## Configuration Management

### Best Practices

**1. Never Hardcode Credentials**

```yaml
# ❌ Bad
password: MySecretPassword123

# ✅ Good
password: {{ env_var('DB_PASSWORD') }}  # From environment
```

**2. Use DBT Variables for Business Logic**

```yaml
# ❌ Bad (hardcoded in SQL)
WHERE revenue > 1000

# ✅ Good (configurable)
WHERE revenue > {{ var('high_value_threshold') }}
```

**3. Environment-Specific Configuration**

```yaml
# profiles.yml - Use target-specific settings
prod:
  threads: 8

dev:
  threads: 4
```

**4. Keep Secrets in GitHub Secrets**

```yaml
# Never commit to Git:
# - Passwords
# - API keys
# - Webhook URLs
# - Tokens

# Store in GitHub Settings → Secrets → Actions
```

### Configuration Testing

**Test Configuration Changes**:

```powershell
# Test DBT connection
docker exec dataops-dbt dbt debug --target dev --profiles-dir .

# Test Docker Compose configuration
docker-compose config

# Test Airflow DAG parsing
docker exec dataops-airflow-scheduler python /opt/airflow/dags/dbt_pipeline_dag.py
```

### Version Control

**Track in Git**:

- ✅ `dbt/profiles.yml` (without passwords)
- ✅ `docker-compose.yml`
- ✅ `.github/workflows/*.yml`
- ✅ `dbt/dbt_project.yml`

**Don't Track in Git**:

- ❌ `.env` (contains secrets)
- ❌ `airflow/logs/` (runtime logs)
- ❌ `dbt/target/` (compiled artifacts)
- ❌ `dbt/logs/` (DBT logs)

---

## Environment Comparison Matrix

| Feature             | Development         | CI                   | Production             |
| ------------------- | ------------------- | -------------------- | ---------------------- |
| **Purpose**         | Local dev & testing | Automated PR testing | Production operation   |
| **Infrastructure**  | Local Docker        | GitHub-hosted runner | Self-hosted runner     |
| **Trigger**         | Manual              | PR open/update       | Push to main           |
| **Data**            | Persistent          | Ephemeral            | Persistent             |
| **Threads**         | 4                   | 2                    | 8                      |
| **UI Access**       | Yes (localhost)     | No                   | Admin only             |
| **Logs**            | Local files         | GitHub Actions       | GitHub Actions + Slack |
| **Deployment Time** | Manual (~5 min)     | Automatic (~3 min)   | Automatic (~5 min)     |
| **Rollback**        | Manual              | N/A                  | Automated workflow     |
| **Monitoring**      | Local logs          | GitHub checks        | Slack + GitHub         |
| **Access**          | Developer           | Automated            | Admin only             |

---

## Related Documentation

- **[DEPLOYMENT_RUNBOOK.md](DEPLOYMENT_RUNBOOK.md)** - Deployment procedures and troubleshooting
- **[SELF_HOSTED_RUNNER_SETUP.md](SELF_HOSTED_RUNNER_SETUP.md)** - CI/CD runner setup guide
- **[TESTING_STRATEGY.md](TESTING_STRATEGY.md)** - Testing approach across environments
- **[ARCHITECTURE_DIAGRAM.md](ARCHITECTURE_DIAGRAM.md)** - System architecture overview

---

**Last Updated**: December 2025  
**Version**: 1.0.0  
**Maintained By**: DataOps Project Team
