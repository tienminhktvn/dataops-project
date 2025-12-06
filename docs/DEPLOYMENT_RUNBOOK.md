# 📘 Deployment Runbook

> **Comprehensive guide for deploying and operating the DataOps pipeline**
> Version: 1.0 | Last Updated: 2024-01-15

---

## 📋 Table of Contents

1. [Pre-Deployment Checklist](#pre-deployment-checklist)
2. [Deployment Procedures](#deployment-procedures)
3. [Environment-Specific Deployment](#environment-specific-deployment)
4. [Rollback Procedures](#rollback-procedures)
5. [Health Checks](#health-checks)
6. [Troubleshooting Guide](#troubleshooting-guide)
7. [Incident Response](#incident-response)
8. [Monitoring & Alerts](#monitoring--alerts)

---

## 🔍 Pre-Deployment Checklist

### Before Every Deployment

- [ ] **Code Review Completed**
  - PR approved by at least 1 team member
  - All CI checks passing
  - No merge conflicts

- [ ] **Testing Validation**
  - All DBT tests passing locally
  - Data quality checks verified
  - No failing unit tests

- [ ] **Documentation Updated**
  - Model descriptions current
  - Schema.yml updated for new columns
  - README reflects any new features

- [ ] **Database Readiness**
  - Source database accessible
  - Connection credentials valid
  - Target schema permissions verified

- [ ] **Backup Verified**
  - Previous deployment backup exists
  - Backup restoration tested (production only)

- [ ] **Team Notification**
  - Deployment window communicated
  - On-call engineer identified
  - Stakeholders notified (production only)

### Production-Only Checklist

- [ ] **Change Management**
  - Change ticket created and approved
  - Deployment scheduled during maintenance window
  - Rollback plan documented

- [ ] **Capacity Planning**
  - Database capacity sufficient
  - Pipeline execution time estimated
  - SLA requirements reviewed

---

## 🚀 Deployment Procedures

### 1. Development Environment Deployment

#### Manual Deployment (Local Docker)

```bash
# Step 1: Start infrastructure
cd /path/to/dataops-project
docker-compose up -d

# Step 2: Wait for services to be healthy
docker-compose ps
# Ensure all services show "healthy" status

# Step 3: Install DBT dependencies
docker exec dataops-dbt dbt deps --profiles-dir /usr/app/dbt

# Step 4: Run DBT models
docker exec dataops-dbt dbt run --profiles-dir /usr/app/dbt --target dev

# Step 5: Execute tests
docker exec dataops-dbt dbt test --profiles-dir /usr/app/dbt --target dev

# Step 6: Generate documentation
docker exec dataops-dbt dbt docs generate --profiles-dir /usr/app/dbt --target dev

# Step 7: Verify deployment
docker exec dataops-dbt dbt source freshness --profiles-dir /usr/app/dbt --target dev

# Step 8: Access Airflow UI
# Open browser: http://localhost:8080
# Username: airflow
# Password: airflow
```

**Expected Duration**: 5-10 minutes

#### Automated Deployment (GitHub Actions)

Triggered automatically on push to `develop` branch:

```yaml
# .github/workflows/cd-deploy.yml handles:
# - Environment detection (develop → dev)
# - Pre-deployment validation
# - DBT model execution
# - Data quality testing
# - Health checks
# - Notifications
```

**Expected Duration**: 10-15 minutes

---

### 2. Production Environment Deployment

#### Prerequisites

1. **Environment Variables Set** (in GitHub Secrets):
   ```
   PROD_SQL_SERVER=<production-server>
   PROD_SQL_DATABASE=<production-database>
   PROD_SQL_USERNAME=<service-account>
   PROD_SQL_PASSWORD=<secure-password>
   PROD_SQL_SCHEMA=<target-schema>
   ```

2. **Production Database Prepared**:
   - Target schema exists: `dbo`, `bronze`, `silver`, `gold`
   - Service account has permissions: `CREATE TABLE`, `SELECT`, `INSERT`, `UPDATE`

#### Deployment Steps

```bash
# Step 1: Merge PR to main branch
# This triggers automatic deployment via GitHub Actions

# Step 2: Monitor deployment progress
# Go to: GitHub → Actions → "CD - Deploy Pipeline"

# Step 3: Verify deployment jobs
# ✅ Pre-Deployment Checks
# ✅ Create Backup (production only)
# ✅ Deploy DBT Models
# ✅ Run DBT Tests
# ✅ Source Freshness Check
# ✅ Generate Documentation
# ✅ Post-Deployment Health Check
# ✅ Send Notifications

# Step 4: Manual verification (after CI/CD completes)
# Connect to production database
USE [AdventureWorks2014];

-- Check Bronze layer
SELECT COUNT(*) FROM bronze.brnz_sales_orders;
SELECT COUNT(*) FROM bronze.brnz_customers;
SELECT COUNT(*) FROM bronze.brnz_products;

-- Check Silver layer
SELECT COUNT(*) FROM silver.slvr_sales_orders;
SELECT COUNT(*) FROM silver.slvr_customers;
SELECT COUNT(*) FROM silver.slvr_products;

-- Check Gold layer
SELECT COUNT(*) FROM gold.gld_sales_summary;
SELECT COUNT(*) FROM gold.gld_customer_metrics;
SELECT COUNT(*) FROM gold.gld_product_performance;

-- Verify data freshness
SELECT MAX(order_date) as latest_order_date FROM silver.slvr_sales_orders;
```

**Expected Duration**: 15-25 minutes

#### Manual Production Deployment (Emergency Only)

```bash
# Only use if GitHub Actions is unavailable

# Step 1: Set environment variables
export DBT_TARGET=prod
export PROD_SQL_SERVER=<server>
export PROD_SQL_DATABASE=<database>
export PROD_SQL_USERNAME=<username>
export PROD_SQL_PASSWORD=<password>

# Step 2: Run deployment
cd dbt/
dbt deps --profiles-dir .
dbt run --profiles-dir . --target prod --full-refresh
dbt test --profiles-dir . --target prod

# Step 3: Document manual deployment
# Create incident ticket with:
# - Reason for manual deployment
# - Who performed it
# - Timestamp
# - Verification results
```

---

## 🌍 Environment-Specific Deployment

### Development Environment

**Purpose**: Feature development and testing

**Deployment Trigger**: Push to `develop` branch

**Configuration**:
```yaml
Target: dev
Database: Local SQL Server (Docker)
Schedule: On-demand
Notifications: Disabled
```

**Rollback**: Not required (reset via docker-compose)

---

### Staging Environment (Optional)

**Purpose**: Pre-production validation

**Deployment Trigger**: Manual via workflow_dispatch

**Configuration**:
```yaml
Target: staging
Database: Staging SQL Server
Schedule: Nightly at 2 AM UTC
Notifications: Slack #data-staging
```

**Rollback**: Available via GitHub Actions

---

### Production Environment

**Purpose**: Live analytics and reporting

**Deployment Trigger**: Push to `main` branch

**Configuration**:
```yaml
Target: prod
Database: Production SQL Server
Schedule: Daily at 1 AM UTC
Notifications: Slack #data-prod + Email
SLA: 2 hours
```

**Rollback**: Available via GitHub Actions (requires approval)

---

## ⏪ Rollback Procedures

### When to Rollback

Execute rollback if:
- Data quality tests fail in production
- Business reports show incorrect data
- Performance degradation (>50% slower)
- Critical bug discovered post-deployment
- Database errors or connection issues

### Automated Rollback (Recommended)

```bash
# Step 1: Go to GitHub Actions
# Navigate to: .github/workflows/cd-rollback.yml

# Step 2: Click "Run workflow"

# Step 3: Fill in parameters:
Environment: prod
Backup SHA: <leave empty for previous commit>
Reason: <brief description of issue>

# Step 4: Confirm and execute

# Step 5: Monitor rollback progress
# ✅ Validate Rollback Request
# ✅ Backup Current State
# ✅ Execute Rollback (deploy previous version)
# ✅ Run Verification Tests
# ✅ Verify Rollback Success
# ✅ Notify Team
```

**Expected Duration**: 10-15 minutes

### Manual Rollback

```bash
# Step 1: Identify target commit SHA
git log --oneline -10
# Example output:
# abc1234 (HEAD) Fix: Update customer segmentation
# def5678 Feat: Add product performance metrics
# ghi9012 Feat: Implement RFM analysis

# Step 2: Checkout previous commit
git checkout def5678

# Step 3: Deploy previous version
cd dbt/
dbt deps --profiles-dir .
dbt run --profiles-dir . --target prod --full-refresh

# Step 4: Run tests
dbt test --profiles-dir . --target prod

# Step 5: Verify rollback
# Query production database to verify data correctness

# Step 6: Document rollback
# Create post-incident report with:
# - Root cause analysis
# - Timeline of events
# - Corrective actions
```

### Post-Rollback Actions

1. **Immediate** (within 1 hour):
   - [ ] Verify all reports are accurate
   - [ ] Check Airflow DAG status
   - [ ] Notify stakeholders of rollback completion

2. **Short-term** (within 24 hours):
   - [ ] Identify root cause of failure
   - [ ] Create bug fix PR
   - [ ] Add regression tests
   - [ ] Update deployment checklist

3. **Long-term** (within 1 week):
   - [ ] Conduct post-incident review
   - [ ] Update runbook with lessons learned
   - [ ] Implement additional safeguards
   - [ ] Train team on new procedures

---

## 🏥 Health Checks

### Automated Health Checks (CI/CD)

The deployment workflow includes automatic health checks:

```python
# Post-deployment health validation
def check_pipeline_health():
    checks = {
        'bronze_tables_exist': verify_bronze_layer(),
        'silver_tables_exist': verify_silver_layer(),
        'gold_tables_exist': verify_gold_layer(),
        'row_counts_valid': verify_row_counts(),
        'data_quality_passing': verify_test_results(),
        'freshness_acceptable': verify_source_freshness()
    }

    return all(checks.values())
```

### Manual Health Checks

#### Database Health Check

```sql
-- Check 1: All tables exist
SELECT
    SCHEMA_NAME(schema_id) as schema_name,
    name as table_name,
    create_date,
    modify_date
FROM sys.tables
WHERE SCHEMA_NAME(schema_id) IN ('bronze', 'silver', 'gold')
ORDER BY schema_name, table_name;

-- Expected: 9 tables (3 per layer)

-- Check 2: Row counts within expected ranges
SELECT 'bronze.brnz_sales_orders' as table_name, COUNT(*) as row_count FROM bronze.brnz_sales_orders
UNION ALL
SELECT 'bronze.brnz_customers', COUNT(*) FROM bronze.brnz_customers
UNION ALL
SELECT 'bronze.brnz_products', COUNT(*) FROM bronze.brnz_products
UNION ALL
SELECT 'silver.slvr_sales_orders', COUNT(*) FROM silver.slvr_sales_orders
UNION ALL
SELECT 'silver.slvr_customers', COUNT(*) FROM silver.slvr_customers
UNION ALL
SELECT 'silver.slvr_products', COUNT(*) FROM silver.slvr_products
UNION ALL
SELECT 'gold.gld_sales_summary', COUNT(*) FROM gold.gld_sales_summary
UNION ALL
SELECT 'gold.gld_customer_metrics', COUNT(*) FROM gold.gld_customer_metrics
UNION ALL
SELECT 'gold.gld_product_performance', COUNT(*) FROM gold.gld_product_performance;

-- Expected ranges (AdventureWorks 2014):
-- Bronze: 30K-35K orders, 19K customers, 500 products
-- Silver: Same as bronze
-- Gold: 1.5K daily summaries, 19K customer metrics, 500 product metrics

-- Check 3: Data freshness
SELECT
    'Sales Orders' as data_source,
    MAX(order_date) as latest_date,
    DATEDIFF(day, MAX(order_date), GETDATE()) as days_old
FROM silver.slvr_sales_orders;

-- Expected: Latest date should be recent (depending on source data)

-- Check 4: No null critical fields
SELECT
    'Bronze Sales Orders - Null Check' as check_name,
    COUNT(*) as null_count
FROM bronze.brnz_sales_orders
WHERE sales_order_id IS NULL
   OR order_date IS NULL
   OR customer_id IS NULL;

-- Expected: 0 null values

-- Check 5: Data quality metrics
SELECT
    customer_segment,
    COUNT(*) as customer_count,
    AVG(lifetime_value) as avg_ltv
FROM silver.slvr_customers
GROUP BY customer_segment
ORDER BY customer_count DESC;

-- Expected: Reasonable distribution across segments
```

#### Airflow Health Check

```bash
# Check Airflow webserver
curl -f http://localhost:8080/health || echo "Airflow webserver down"

# Check DAG status
docker exec dataops-airflow-webserver airflow dags list
# Expected: dbt_dataops_pipeline should be listed

# Check last DAG run
docker exec dataops-airflow-webserver airflow dags list-runs -d dbt_dataops_pipeline
# Expected: Recent runs should show "success" state

# Check for failed tasks
docker exec dataops-airflow-webserver airflow tasks states-for-dag-run dbt_dataops_pipeline <run_id>
# Expected: All tasks should be "success"
```

#### DBT Health Check

```bash
# Check DBT compilation
docker exec dataops-dbt dbt compile --profiles-dir /usr/app/dbt --target dev
# Expected: "Compilation completed successfully"

# Check DBT connection
docker exec dataops-dbt dbt debug --profiles-dir /usr/app/dbt --target dev
# Expected: All checks should pass

# Check DBT tests
docker exec dataops-dbt dbt test --profiles-dir /usr/app/dbt --target dev
# Expected: "Completed successfully"
```

---

## 🔧 Troubleshooting Guide

### Issue 1: DBT Compilation Fails

**Symptoms**:
- `dbt compile` fails with syntax error
- CI/CD pipeline fails at compilation step

**Diagnosis**:
```bash
# Check DBT compilation with verbose logging
dbt compile --profiles-dir . --target dev --log-level debug

# Common error: Undefined macro
# Solution: Check packages.yml and run dbt deps
```

**Solution**:
1. Review error message for specific file and line number
2. Check SQL syntax in the problematic model
3. Verify all Jinja macros are properly imported
4. Ensure `dbt deps` was run to install packages
5. Clear DBT cache: `dbt clean`

---

### Issue 2: Database Connection Fails

**Symptoms**:
- `dbt debug` fails with connection error
- "Cannot connect to database" message

**Diagnosis**:
```bash
# Test database connection manually
sqlcmd -S localhost,1433 -U sa -P YourPassword -Q "SELECT @@VERSION"

# Check Docker network
docker network inspect dataops-project_default

# Check environment variables
echo $PROD_SQL_SERVER
echo $PROD_SQL_DATABASE
```

**Solution**:
1. **Docker environment**: Ensure SQL Server container is running and healthy
   ```bash
   docker-compose ps sqlserver
   docker-compose logs sqlserver
   ```

2. **Production environment**: Verify credentials and network access
   ```bash
   # Test from CI/CD runner
   nslookup $PROD_SQL_SERVER
   telnet $PROD_SQL_SERVER 1433
   ```

3. **Firewall**: Ensure port 1433 is open
4. **Credentials**: Rotate if expired (common in production)

---

### Issue 3: Tests Fail After Deployment

**Symptoms**:
- `dbt test` fails for specific models
- Data quality alerts triggered

**Diagnosis**:
```bash
# Run specific test with verbose output
dbt test --select test_name --profiles-dir . --target dev --log-level debug

# Query database to investigate
# Example: Check for null values
SELECT COUNT(*)
FROM silver.slvr_customers
WHERE customer_id IS NULL;
```

**Solution**:
1. **Schema test failure** (unique, not_null, etc.):
   - Query the table to identify problematic rows
   - Trace back to source data
   - Add data cleaning logic in Bronze/Silver layer

2. **Custom test failure**:
   - Review test logic in `tests/generic/`
   - Check if test parameters need adjustment
   - Verify test assumptions are still valid

3. **Relationships test failure**:
   - Identify orphaned records
   - Check for source data integrity issues
   - Consider adding soft deletes handling

---

### Issue 4: Airflow DAG Not Running

**Symptoms**:
- DAG not visible in Airflow UI
- DAG shows "Import Error"
- Tasks not executing

**Diagnosis**:
```bash
# Check Airflow logs
docker-compose logs airflow-scheduler
docker-compose logs airflow-webserver

# List DAGs
docker exec dataops-airflow-webserver airflow dags list

# Check DAG import errors
docker exec dataops-airflow-webserver airflow dags list-import-errors
```

**Solution**:
1. **Import Error**:
   - Check Python syntax in `dbt_pipeline_dag.py`
   - Verify all imports are available
   - Ensure DAG file is in correct directory (`airflow/dags/`)

2. **DAG Paused**:
   - Unpause in Airflow UI
   - Or via CLI: `airflow dags unpause dbt_dataops_pipeline`

3. **Schedule Issue**:
   - Verify cron schedule is correct
   - Check `start_date` is in the past
   - Ensure `catchup=False` to avoid backfilling

---

### Issue 5: Slow Performance

**Symptoms**:
- DBT run takes >1 hour (expected: 15-30 min)
- Database queries timing out
- Airflow DAG exceeds SLA

**Diagnosis**:
```sql
-- Check query execution stats
SELECT
    creation_time,
    last_execution_time,
    execution_count,
    total_elapsed_time / 1000000 as total_elapsed_sec,
    SUBSTRING(st.text, 1, 200) as query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY total_elapsed_time DESC;

-- Check table sizes
SELECT
    t.name as table_name,
    p.rows as row_count,
    SUM(a.total_pages) * 8 / 1024 as total_size_mb
FROM sys.tables t
INNER JOIN sys.indexes i ON t.object_id = i.object_id
INNER JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
WHERE t.schema_id = SCHEMA_ID('silver')
GROUP BY t.name, p.rows
ORDER BY total_size_mb DESC;
```

**Solution**:
1. **Add indexes** to frequently joined columns:
   ```sql
   CREATE INDEX idx_customer_id ON silver.slvr_sales_orders(customer_id);
   CREATE INDEX idx_product_id ON silver.slvr_sales_orders(product_id);
   ```

2. **Use incremental models** for large tables:
   ```sql
   -- In model config
   {{ config(
       materialized='incremental',
       unique_key='sales_order_id'
   ) }}
   ```

3. **Partition large tables** by date:
   ```sql
   CREATE PARTITION FUNCTION pf_order_date (DATE)
   AS RANGE RIGHT FOR VALUES ('2023-01-01', '2024-01-01');
   ```

4. **Optimize Silver/Gold queries**:
   - Reduce window function usage
   - Pre-aggregate in Bronze where possible
   - Use CTEs for complex logic

---

### Issue 6: Rollback Fails

**Symptoms**:
- Rollback workflow fails
- Cannot restore to previous version

**Diagnosis**:
```bash
# Check rollback workflow logs
# GitHub Actions → "CD - Rollback Deployment" → View logs

# Verify backup exists
# GitHub Actions → Artifacts → "deployment-backup-{sha}"
```

**Solution**:
1. **Manual rollback** using git:
   ```bash
   # Find last good commit
   git log --oneline --graph --all

   # Checkout and deploy
   git checkout <good-commit-sha>
   cd dbt/
   dbt run --profiles-dir . --target prod --full-refresh
   ```

2. **Database restore** (if needed):
   ```sql
   -- Restore from backup
   RESTORE DATABASE [AdventureWorks2014_Backup]
   FROM DISK = 'C:\Backup\AdventureWorks2014.bak'
   WITH REPLACE;
   ```

3. **Contact DBA** if permissions issues

---

## 🚨 Incident Response

### Severity Levels

#### P0 - Critical (Production Down)
- **Definition**: Production pipeline completely broken, no data flowing
- **Response Time**: Immediate (within 15 minutes)
- **Actions**:
  1. Page on-call engineer immediately
  2. Initiate rollback immediately
  3. Notify stakeholders within 15 minutes
  4. Create incident channel (#incident-YYYYMMDD)
  5. Start incident timeline documentation

#### P1 - High (Degraded Service)
- **Definition**: Partial pipeline failure, some data incorrect
- **Response Time**: Within 1 hour
- **Actions**:
  1. Notify on-call engineer
  2. Assess impact and scope
  3. Determine rollback vs. hotfix
  4. Notify affected stakeholders

#### P2 - Medium (Non-Critical Issue)
- **Definition**: Minor data quality issues, non-blocking
- **Response Time**: Within 4 hours
- **Actions**:
  1. Create bug ticket
  2. Schedule fix in next sprint
  3. Add monitoring if needed

#### P3 - Low (Cosmetic Issue)
- **Definition**: Documentation errors, minor performance issues
- **Response Time**: Within 1 week
- **Actions**:
  1. Add to backlog
  2. Fix in next maintenance window

### Incident Communication Template

```markdown
## Incident Summary

**Incident ID**: INC-YYYYMMDD-001
**Severity**: P0 / P1 / P2 / P3
**Status**: Investigating / Identified / Monitoring / Resolved
**Started**: YYYY-MM-DD HH:MM UTC
**Resolved**: YYYY-MM-DD HH:MM UTC (if resolved)

### Impact
- **Affected Services**: [e.g., Gold layer, Customer reports]
- **User Impact**: [e.g., Dashboard showing stale data]
- **Data Impact**: [e.g., 5,000 records incorrect]

### Timeline
- **10:00 UTC**: Issue detected via monitoring alert
- **10:05 UTC**: On-call engineer paged
- **10:15 UTC**: Root cause identified (DBT test failure)
- **10:20 UTC**: Rollback initiated
- **10:35 UTC**: Rollback completed, service restored

### Root Cause
[Detailed explanation of what went wrong]

### Resolution
[Steps taken to resolve the issue]

### Prevention
- [ ] Add regression test
- [ ] Update deployment checklist
- [ ] Implement additional monitoring
- [ ] Team training on X

### Follow-up Actions
- [ ] Post-incident review scheduled
- [ ] Update runbook with lessons learned
- [ ] Implement preventive measures
```

---

## 📊 Monitoring & Alerts

### Key Metrics to Monitor

1. **Pipeline Health**:
   - DAG run success rate (target: >99%)
   - Average execution time (target: <30 minutes)
   - Test failure rate (target: <1%)

2. **Data Quality**:
   - Row count anomalies (alert if >20% change)
   - Null value percentage (alert if >5%)
   - Duplicate records (alert if >0)

3. **Performance**:
   - Database CPU usage (alert if >80%)
   - Query execution time (alert if >5 minutes)
   - Disk space (alert if <20% free)

4. **Business Metrics**:
   - Daily revenue match expected range
   - Customer count trends
   - Product performance metrics

### Alert Configuration

```yaml
# Example Airflow SLA configuration (already in dbt_pipeline_dag.py)
DEFAULT_ARGS = {
    'sla': timedelta(hours=2),
    'sla_miss_callback': send_failure_notification,
    'email_on_failure': True,
    'email': ['dataops-team@example.com']
}

# Example data quality alert (to be implemented)
alert_config:
  - name: row_count_anomaly
    metric: row_count_change_percentage
    threshold: 20
    severity: P1
    notification: slack

  - name: test_failure
    metric: test_failure_count
    threshold: 1
    severity: P0
    notification: pagerduty
```

### Monitoring Dashboards

1. **Operational Dashboard**:
   - Real-time DAG status
   - Recent test results
   - System health indicators

2. **Data Quality Dashboard**:
   - Test pass/fail trends
   - Data freshness metrics
   - Anomaly detection results

3. **Business Metrics Dashboard**:
   - Daily sales trends
   - Customer segmentation distribution
   - Product performance KPIs

---

## 📞 Contacts & Escalation

### Team Contacts

| Role | Contact | Responsibility |
|------|---------|----------------|
| Data Engineering Lead | lead@example.com | Overall pipeline ownership |
| On-Call Engineer | oncall@example.com | 24/7 incident response |
| Database Administrator | dba@example.com | Database issues, performance |
| DevOps Engineer | devops@example.com | Infrastructure, CI/CD |
| Business Analyst | analytics@example.com | Data quality validation |

### Escalation Path

1. **Level 1**: On-call Data Engineer (0-30 minutes)
2. **Level 2**: Data Engineering Lead (30-60 minutes)
3. **Level 3**: Engineering Manager (1-2 hours)
4. **Level 4**: CTO (2+ hours, P0 only)

---

## 📚 Additional Resources

- **Architecture Documentation**: [ARCHITECTURE.md](./ARCHITECTURE.md)
- **CI/CD Guide**: [CI_CD_GUIDE.md](./CI_CD_GUIDE.md)
- **Testing Strategy**: [TESTING_STRATEGY.md](./TESTING_STRATEGY.md)
- **Multi-Environment Setup**: [MULTI_ENVIRONMENT_SETUP.md](./MULTI_ENVIRONMENT_SETUP.md)
- **Data Lineage**: [DATA_LINEAGE.md](./DATA_LINEAGE.md)
- **DBT Documentation**: http://localhost:8001 (when running locally)
- **Airflow UI**: http://localhost:8080 (when running locally)

---

## 📝 Runbook Maintenance

This runbook should be updated:
- After every incident (add lessons learned)
- When new features are deployed
- Quarterly review for accuracy
- When team structure changes

**Last Reviewed**: 2024-01-15
**Next Review Due**: 2024-04-15
**Maintained By**: Data Engineering Team

---

**Questions or Issues?**
Create a ticket: https://github.com/your-org/dataops-project/issues
Slack: #dataops-support
