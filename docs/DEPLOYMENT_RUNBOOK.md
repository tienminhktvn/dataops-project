# 🚀 Deployment Runbook

> **Comprehensive operational guide for deploying and managing the DataOps pipeline**

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Pre-Deployment Checklist](#pre-deployment-checklist)
3. [Local Development Deployment](#local-development-deployment)
4. [CI/CD Automated Deployment](#cicd-automated-deployment)
5. [Production Deployment](#production-deployment)
6. [Rollback Procedures](#rollback-procedures)
7. [Health Checks](#health-checks)
8. [Troubleshooting](#troubleshooting)
9. [Monitoring & Alerts](#monitoring--alerts)

---

## Overview

### Deployment Strategy

| Environment   | Trigger           | Runner        | Target | Auto Deploy |
| ------------- | ----------------- | ------------- | ------ | ----------- |
| **Local Dev** | Manual            | Local machine | dev    | No          |
| **CI**        | Pull Request      | GitHub-hosted | ci     | Automatic   |
| **Dev**       | Push to `develop` | Self-hosted   | dev    | Automatic   |
| **Prod**      | Push to `main`    | Self-hosted   | prod   | Automatic   |

### Deployment Architecture

```
Code Push (GitHub)
       │
       ├─── Pull Request
       │         │
       │         ▼
       │    GitHub-hosted Runner (CI)
       │         │
       │         └─ DBT Test
       │         └─ Lint Check
       │         └─ PR Validation
       │
       ├─── Push to develop
       │         │
       │         ▼
       │    Self-hosted Runner (Dev)
       │         │
       │         └─ Deploy to Dev Environment
       │         └─ Health Check
       │         └─ Smoke Tests
       │
       └─── Push to main
                 │
                 ▼
            Self-hosted Runner (Prod)
                 │
                 └─ Create Backup
                 └─ Deploy to Prod
                 └─ Validate
                 └─ Slack Notification
```

---

## Pre-Deployment Checklist

### 1. Environment Validation

**Check Docker Environment**:

```powershell
# Verify Docker is running
docker info

# Check available disk space (need at least 5GB)
Get-PSDrive C

# Verify Docker Compose version
docker-compose --version
```

**Check Git Status**:

```powershell
# Ensure you're on the correct branch
git branch --show-current

# Check for uncommitted changes
git status

# Verify remote connection
git remote -v
```

### 2. Dependency Validation

**Verify Required Files**:

```powershell
# Check critical files exist
Test-Path docker-compose.yml
Test-Path dbt/dbt_project.yml
Test-Path dbt/profiles.yml
Test-Path airflow/dags/dbt_pipeline_dag.py
```

**Validate Configuration**:

```powershell
# Check DBT project configuration
docker run --rm -v ${PWD}/dbt:/usr/app dbt-sqlserver dbt debug --profiles-dir .

# Validate Docker Compose file
docker-compose config
```

### 3. Credential Check

**Required Secrets**:

- ✅ SQL Server SA password
- ✅ Postgres password (Airflow metadata)
- ✅ Slack webhook URL (optional, for notifications)

**Verify Environment Variables**:

```powershell
# Check .env file exists
Get-Content .env

# Required variables:
# - SLACK_WEBHOOK_URL (optional)
```

### 4. Database Readiness

**SQL Server**:

```powershell
# Verify SQL Server container health
docker ps --filter "name=dataops-sqlserver"

# Test SQL Server connection
docker exec dataops-sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P YourPassword123! -Q "SELECT @@VERSION"
```

**Postgres (Airflow Metadata)**:

```powershell
# Check Postgres is healthy
docker exec dataops-postgres pg_isready -U airflow
```

---

## Local Development Deployment

### Step 1: Clone Repository

```powershell
# Clone the project
git clone https://github.com/tienminhktvn/dataops-project.git
cd dataops-project

# Checkout develop branch
git checkout develop
```

### Step 2: Configure Environment

```powershell
# Create .env file for Slack notifications (optional)
echo "SLACK_WEBHOOK_URL=your_webhook_url_here" > .env

# Verify DBT profiles
cat dbt/profiles.yml
```

### Step 3: Start Infrastructure

```powershell
# Build and start all containers
docker-compose up -d --build

# Expected output:
# ✓ Container dataops-sqlserver        Started
# ✓ Container dataops-postgres         Started
# ✓ Container dataops-airflow-webserver Started
# ✓ Container dataops-airflow-scheduler Started
# ✓ Container dataops-dbt              Started
# ✓ Container cloudbeaver              Started
```

### Step 4: Wait for Services

```powershell
# Wait for SQL Server (takes ~30-60 seconds)
Start-Sleep -Seconds 60

# Check container health
docker ps

# All containers should show STATUS as "Up" or "healthy"
```

### Step 5: Restore Database

```powershell
# Restore AdventureWorks2014 database
docker exec dataops-sqlserver /bin/bash /tmp/restore_db.sh

# Verify database restored
docker exec dataops-sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P YourPassword123! -Q "SELECT name FROM sys.databases WHERE name = 'AdventureWorks2014'"
```

### Step 6: Run DBT Models

```powershell
# Test DBT connection
docker exec dataops-dbt dbt debug --profiles-dir .

# Install DBT packages
docker exec dataops-dbt dbt deps --profiles-dir .

# Run all models
docker exec dataops-dbt dbt run --target dev --profiles-dir .

# Expected output:
# Completed successfully
# Done. PASS=9 WARN=0 ERROR=0 SKIP=0 TOTAL=9
```

### Step 7: Run Tests

```powershell
# Run data quality tests
docker exec dataops-dbt dbt test --target dev --profiles-dir .

# Expected: All tests pass
```

### Step 8: Access UIs

**Airflow Web UI**:

- URL: http://localhost:8080
- Username: `admin`
- Password: `admin`

**CloudBeaver (SQL UI)**:

- URL: http://localhost:8978

**DBT Documentation**:

```powershell
# Generate and serve DBT docs
docker exec dataops-dbt dbt docs generate --profiles-dir .
docker exec -d dataops-dbt dbt docs serve --port 8001 --profiles-dir .
```

- URL: http://localhost:8001

---

## CI/CD Automated Deployment

### CI Pipeline (Pull Request)

**Triggered By**:

- Opening a Pull Request
- Pushing new commits to an open PR

**Workflow**: `.github/workflows/ci-dbt-test.yml`

**Steps**:

1. ✅ Checkout code
2. ✅ Start SQL Server container
3. ✅ Restore AdventureWorks database
4. ✅ Build DBT image
5. ✅ Run `dbt deps`
6. ✅ Run `dbt parse` (validate SQL)
7. ✅ Run `dbt run --target ci`
8. ✅ Run `dbt test --target ci`
9. ✅ Generate coverage report
10. ✅ Comment results on PR

**Example PR Comment**:

```
✅ DBT Pipeline Tests Passed

📊 Test Results:
- Total Tests: 50
- Passed: 50
- Failed: 0
- Warnings: 0

🎯 Models Built:
- Bronze: 3
- Silver: 3
- Gold: 3

✨ All checks passed successfully!
```

### CD Pipeline (Development)

**Triggered By**:

- Push to `develop` branch
- Manual workflow dispatch (dev environment)

**Workflow**: `.github/workflows/cd-deploy.yml`

**Runner**: Self-hosted (Ubuntu)

**Steps**:

1. **Determine Environment**: Resolve to `dev` target
2. **Checkout Code**: Pull latest code from `develop`
3. **Restart Containers**:
   - Stop all containers
   - Fix permissions on Airflow directories
   - Rebuild and restart with `docker-compose up -d --build`
4. **Wait for Health**: Sleep 60s for services to be ready
5. **Database Restore**: Ensure AdventureWorks is available
6. **Run DBT**:
   - Install dependencies (`dbt deps`)
   - Run models (`dbt run --target dev`)
   - Run tests (`dbt test --target dev`)
7. **Validate**: Check Airflow DAG is registered
8. **Notification**: Send success/failure to Slack (optional)

**Deployment Time**: ~3-5 minutes

### CD Pipeline (Production)

**Triggered By**:

- Push to `main` branch
- Manual workflow dispatch (prod environment)

**Workflow**: `.github/workflows/cd-deploy.yml`

**Runner**: Self-hosted (Ubuntu)

**Steps**:

1. **Determine Environment**: Resolve to `prod` target
2. **Create Backup**: Create metadata file with commit SHA
3. **Checkout Code**: Pull latest code from `main`
4. **Restart Containers**: Same as dev but with prod config
5. **Wait for Health**: Sleep 60s
6. **Database Restore**: Ensure production data is ready
7. **Run DBT**:
   - Install dependencies (`dbt deps`)
   - Run models (`dbt run --target prod`)
   - Run tests (`dbt test --target prod`)
8. **Validate**: Comprehensive health checks
9. **Notification**: Send success/failure to Slack

**Deployment Time**: ~4-6 minutes

**Production-Specific Safeguards**:

- ✅ Backup metadata created before deployment
- ✅ Concurrency control (no parallel deploys)
- ✅ Full test suite required to pass
- ✅ Slack notification for visibility

---

## Production Deployment

### Manual Production Deployment

If you need to deploy to production manually:

```powershell
# 1. Ensure you're on main branch
git checkout main
git pull origin main

# 2. Create backup point
git tag -a "backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')" -m "Pre-deployment backup"
git push origin --tags

# 3. Stop containers
docker-compose down

# 4. Fix permissions
docker run --rm -v ${PWD}/airflow:/opt/airflow alpine sh -c "chmod -R 777 /opt/airflow"

# 5. Deploy
docker-compose up -d --build

# 6. Wait for services
Start-Sleep -Seconds 60

# 7. Restore database
docker exec dataops-sqlserver /bin/bash /tmp/restore_db.sh

# 8. Run DBT (production target)
docker exec dataops-dbt dbt deps --profiles-dir .
docker exec dataops-dbt dbt run --target prod --profiles-dir .
docker exec dataops-dbt dbt test --target prod --profiles-dir .

# 9. Validate Airflow DAG
docker exec dataops-airflow-scheduler airflow dags list | Select-String "dbt_dataops_pipeline"
```

### Zero-Downtime Deployment (Future)

For production systems requiring zero downtime, consider:

1. **Blue-Green Deployment**:

   - Maintain two identical environments
   - Deploy to inactive (green) environment
   - Switch traffic after validation
   - Keep blue as rollback option

2. **Rolling Updates**:
   - Deploy to one Airflow scheduler at a time
   - Keep at least one scheduler active
   - Validate before moving to next

**Note**: Current setup uses single-instance deployment suitable for development and small-scale production.

---

## Rollback Procedures

### Automated Rollback

**Workflow**: `.github/workflows/cd-rollback.yml`

**Trigger**: Manual (workflow_dispatch)

**Required Inputs**:

- `environment`: dev or prod
- `backup_sha`: Commit SHA to rollback to (optional, defaults to HEAD~1)
- `reason`: Reason for rollback (required for audit)

**Example Rollback**:

```bash
# Via GitHub UI:
1. Go to Actions tab
2. Select "CD - Rollback Deployment"
3. Click "Run workflow"
4. Fill in:
   - Environment: prod
   - Backup SHA: abc123def (or leave empty for previous commit)
   - Reason: "Critical bug in sales calculation"
5. Click "Run workflow"
```

**Rollback Steps**:

1. **Validate**: Check target commit exists
2. **Checkout**: Switch to target commit SHA
3. **Create .env**: Inject Slack webhook
4. **Restart Containers**: Rebuild with old code
5. **Wait for Health**: 60 seconds
6. **Restore Database**: Ensure database is ready
7. **Run DBT**: Execute with target environment
8. **Validate**: Check DBT models and Airflow DAG
9. **Notify**: Send rollback confirmation

**Rollback Time**: ~3-5 minutes

### Manual Rollback

If automated rollback fails:

```powershell
# 1. Identify target commit
git log --oneline -10

# 2. Checkout target commit
git checkout <commit_sha>

# 3. Stop containers
docker-compose down

# 4. Clear volumes (if needed)
docker volume rm dataops-project_sqlserver_data
docker volume rm dataops-project_postgres_data

# 5. Restart containers
docker-compose up -d --build

# 6. Wait for services
Start-Sleep -Seconds 60

# 7. Restore database
docker exec dataops-sqlserver /bin/bash /tmp/restore_db.sh

# 8. Run DBT with appropriate target
docker exec dataops-dbt dbt deps --profiles-dir .
docker exec dataops-dbt dbt run --target prod --profiles-dir .
docker exec dataops-dbt dbt test --target prod --profiles-dir .

# 9. Validate
docker exec dataops-airflow-scheduler airflow dags list
docker exec dataops-dbt dbt run-operation test_source_freshness --target prod --profiles-dir .
```

### Rollback Validation

After rollback, verify:

```powershell
# Check containers are running
docker ps

# Verify Airflow DAG is active
docker exec dataops-airflow-scheduler airflow dags list | Select-String "dbt_dataops_pipeline"

# Check DBT models exist
docker exec dataops-sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P YourPassword123! -Q "SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA IN ('bronze', 'silver', 'gold')"

# Test data quality
docker exec dataops-dbt dbt test --target prod --profiles-dir .
```

---

## Health Checks

### Container Health

```powershell
# Check all containers are running
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Expected:
# dataops-sqlserver        Up      0.0.0.0:1433->1433/tcp
# dataops-postgres         Up      0.0.0.0:5432->5432/tcp
# dataops-airflow-webserver Up     0.0.0.0:8080->8080/tcp
# dataops-airflow-scheduler Up
# dataops-dbt              Up
# cloudbeaver              Up      0.0.0.0:8978->8978/tcp
```

### Database Health

```powershell
# SQL Server
docker exec dataops-sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P YourPassword123! -Q "SELECT @@VERSION"

# Postgres
docker exec dataops-postgres pg_isready -U airflow

# Check AdventureWorks database
docker exec dataops-sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P YourPassword123! -Q "SELECT COUNT(*) as table_count FROM AdventureWorks2014.INFORMATION_SCHEMA.TABLES"
```

### DBT Health

```powershell
# Test DBT connection
docker exec dataops-dbt dbt debug --target dev --profiles-dir .

# Check DBT models
docker exec dataops-dbt dbt ls --target dev --profiles-dir .

# Run smoke test (one model)
docker exec dataops-dbt dbt run --select brnz_sales_orders --target dev --profiles-dir .
```

### Airflow Health

```powershell
# Check Airflow version
docker exec dataops-airflow-scheduler airflow version

# List DAGs
docker exec dataops-airflow-scheduler airflow dags list

# Check DAG status
docker exec dataops-airflow-scheduler airflow dags state dbt_dataops_pipeline 2025-12-11

# Test DAG execution (dry run)
docker exec dataops-airflow-scheduler airflow dags test dbt_dataops_pipeline 2025-12-11
```

### UI Accessibility

```powershell
# Test Airflow web UI
Invoke-WebRequest -Uri http://localhost:8080 -UseBasicParsing | Select-Object StatusCode

# Test CloudBeaver
Invoke-WebRequest -Uri http://localhost:8978 -UseBasicParsing | Select-Object StatusCode

# Expected: StatusCode = 200 for both
```

---

## Troubleshooting

### Issue 1: Containers Won't Start

**Symptoms**:

- `docker-compose up` fails
- Containers exit immediately

**Diagnosis**:

```powershell
# Check Docker daemon
docker info

# Check logs
docker-compose logs

# Check disk space
Get-PSDrive C
```

**Solutions**:

```powershell
# Free up disk space
docker system prune -a

# Reset Docker Desktop (Windows)
# Settings -> Troubleshoot -> Reset to factory defaults

# Rebuild containers
docker-compose down -v
docker-compose up -d --build
```

---

### Issue 2: SQL Server Connection Failed

**Symptoms**:

- DBT fails with "Cannot connect to SQL Server"
- Error: "Login failed for user 'sa'"

**Diagnosis**:

```powershell
# Check SQL Server container
docker logs dataops-sqlserver

# Test connection
docker exec dataops-sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P YourPassword123! -Q "SELECT 1"
```

**Solutions**:

```powershell
# Wait longer (SQL Server needs 30-60s to start)
Start-Sleep -Seconds 60

# Verify password in profiles.yml matches docker-compose.yml
cat dbt/profiles.yml
cat docker-compose.yml

# Restart SQL Server container
docker restart dataops-sqlserver
Start-Sleep -Seconds 60
```

---

### Issue 3: DBT Models Fail

**Symptoms**:

- `dbt run` completes with errors
- Models not created in database

**Diagnosis**:

```powershell
# Check DBT logs
docker logs dataops-dbt

# Run with debug
docker exec dataops-dbt dbt run --target dev --profiles-dir . --debug
```

**Solutions**:

```powershell
# Check SQL syntax in model files
cat dbt/models/bronze/brnz_sales_orders.sql

# Test individual model
docker exec dataops-dbt dbt run --select brnz_sales_orders --target dev --profiles-dir .

# Clear cache and rebuild
docker exec dataops-dbt dbt clean --profiles-dir .
docker exec dataops-dbt dbt deps --profiles-dir .
docker exec dataops-dbt dbt run --target dev --profiles-dir .
```

---

### Issue 4: Airflow DAG Not Showing

**Symptoms**:

- DAG not visible in Airflow UI
- `airflow dags list` doesn't show pipeline

**Diagnosis**:

```powershell
# Check DAG file exists
Test-Path airflow/dags/dbt_pipeline_dag.py

# Check Airflow logs
docker logs dataops-airflow-scheduler

# Check for Python errors
docker exec dataops-airflow-scheduler python /opt/airflow/dags/dbt_pipeline_dag.py
```

**Solutions**:

```powershell
# Fix Python syntax errors in DAG file
# Check airflow/dags/dbt_pipeline_dag.py

# Restart scheduler
docker restart dataops-airflow-scheduler

# Clear Airflow cache
docker exec dataops-airflow-scheduler airflow dags reserialize

# Check DAG appeared
Start-Sleep -Seconds 30
docker exec dataops-airflow-scheduler airflow dags list
```

---

### Issue 5: Permission Denied Errors

**Symptoms**:

- Airflow logs show "Permission denied"
- Cannot write to `/opt/airflow/logs`

**Diagnosis**:

```powershell
# Check permissions
docker exec dataops-airflow-scheduler ls -la /opt/airflow/logs
```

**Solutions**:

```powershell
# Fix permissions
docker run --rm -v ${PWD}/airflow:/opt/airflow alpine sh -c "chmod -R 777 /opt/airflow/logs /opt/airflow/plugins /opt/airflow/dags"

# Restart Airflow
docker restart dataops-airflow-scheduler
docker restart dataops-airflow-webserver
```

---

### Issue 6: CI/CD Pipeline Fails

**Symptoms**:

- GitHub Actions workflow fails
- Red X on commit/PR

**Diagnosis**:

```bash
# Check workflow logs in GitHub:
# 1. Go to Actions tab
# 2. Click on failed workflow run
# 3. Expand failed step
```

**Common Solutions**:

**DBT Parse Error**:

```yaml
# Fix SQL syntax in model files
# Common issues:
# - Missing commas in SELECT
# - Incorrect column names
# - Invalid Jinja syntax
```

**Docker Build Fails**:

```yaml
# Check Dockerfile syntax
# Verify base image is available
# Check network connectivity in CI runner
```

**Self-Hosted Runner Offline**:

```bash
# On runner machine:
cd actions-runner
./run.sh

# Or as service:
sudo systemctl restart actions.runner.*
```

---

## Monitoring & Alerts

### Key Metrics to Monitor

| Metric           | Threshold   | Check Method     |
| ---------------- | ----------- | ---------------- |
| Container Status | All Up      | `docker ps`      |
| Disk Space       | > 5GB free  | `Get-PSDrive C`  |
| SQL Server CPU   | < 80%       | Docker stats     |
| DBT Run Duration | < 5 minutes | Airflow logs     |
| Test Pass Rate   | 100%        | DBT test results |
| DAG Success Rate | > 95%       | Airflow UI       |

### Slack Notifications

**Setup**:

1. Create Slack Incoming Webhook
2. Add `SLACK_WEBHOOK_URL` to `.env` file
3. Deploy with updated configuration

**Notification Events**:

- ✅ Successful deployment (dev/prod)
- ❌ Failed deployment
- ✅ Successful rollback
- ❌ Failed rollback
- ⚠️ DBT test failures
- ⚠️ Airflow DAG failures

### Log Monitoring

**Airflow Logs**:

```powershell
# Scheduler logs
docker logs -f dataops-airflow-scheduler

# Webserver logs
docker logs -f dataops-airflow-webserver

# DAG run logs
# Available in Airflow UI: http://localhost:8080
# Navigate to: DAGs -> dbt_dataops_pipeline -> Graph -> Click task -> View Log
```

**DBT Logs**:

```powershell
# View DBT run logs
docker exec dataops-dbt cat logs/dbt.log

# Live tail
docker exec dataops-dbt tail -f logs/dbt.log
```

**SQL Server Logs**:

```powershell
# View SQL Server error log
docker logs dataops-sqlserver

# Check for connection errors
docker logs dataops-sqlserver 2>&1 | Select-String "error"
```

---

## Related Documentation

- **[ARCHITECTURE_DIAGRAM.md](ARCHITECTURE_DIAGRAM.md)** - System architecture overview
- **[MULTI_ENVIRONMENT_SETUP.md](MULTI_ENVIRONMENT_SETUP.md)** - Environment configuration details
- **[TESTING_STRATEGY.md](TESTING_STRATEGY.md)** - Testing approach and data quality
- **[SELF_HOSTED_RUNNER_SETUP.md](SELF_HOSTED_RUNNER_SETUP.md)** - CI/CD runner setup

---

**Last Updated**: December 2025  
**Version**: 1.0.0  
**Maintained By**: DataOps Project Team
