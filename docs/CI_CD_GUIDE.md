# CI/CD Guide - DataOps Project

## Overview

Dự án này sử dụng **GitHub Actions** để tự động hóa toàn bộ quá trình CI/CD (Continuous Integration / Continuous Deployment) cho DBT data pipeline.

---

## CI - Continuous Integration

### 1. **DBT Test Workflow** (`ci-dbt-test.yml`)

**Trigger:** Pull Request to `main` or `develop`

**Purpose:** Validate DBT models before merging

**Jobs:**
1. **DBT Compile Check** - Validates SQL syntax
2. **DBT Parse Check** - Validates YAML files
3. **DBT Debug Check** - Validates configuration
4. **Dependency Check** - Detects circular dependencies
5. **Upload Artifacts** - Stores compiled models

**Run time:** ~3-5 minutes

**What it catches:**
- SQL syntax errors
- Invalid YAML structure
- Missing references
- Circular dependencies

---

### 2. **Code Linting Workflow** (`ci-lint.yml`)

**Trigger:** Pull Request to `main` or `develop`

**Purpose:** Enforce code quality standards

**Linters:**
- **SQLFluff**: SQL style and best practices (T-SQL dialect)
- **Flake8**: Python PEP 8 compliance
- **Black**: Python code formatter
- **yamllint**: YAML validation
- **markdownlint**: Markdown style

**Configuration:**
```yaml
# .sqlfluff
dialect = tsql
max_line_length = 120

# .flake8
max-line-length = 120
max-complexity = 10
```

**Run time:** ~2-3 minutes

---

### 3. **PR Validation Workflow** (`ci-pr-validation.yml`)

**Trigger:** Pull Request opened/edited

**Purpose:** Validate PR metadata and prevent issues

**Checks:**
1. **PR Title Format** - Conventional commits format
2. **Merge Conflicts** - Detects conflicts early
3. **File Sizes** - Warns about large files (>1MB)
4. **Sensitive Files** - Prevents credential leaks
5. **PR Description** - Ensures adequate context
6. **Label Suggestions** - Auto-suggests labels

**Run time:** ~1-2 minutes

---

## CD - Continuous Deployment

### 4. **Deployment Workflow** (`cd-deploy.yml`)

**Trigger:** Push to `main` (prod) or `develop` (dev)

**Purpose:** Automatically deploy DBT pipeline

#### Deployment Flow:

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Determine Environment (dev/prod)                         │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Pre-Deployment Checks                                    │
│    - Validate DBT project                                   │
│    - Check for breaking changes                             │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. Create Backup (prod only)                                │
│    - Backup metadata                                        │
│    - Store in artifacts                                     │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. Deploy DBT Models                                        │
│    - dbt deps (install packages)                            │
│    - dbt run (execute models)                               │
│    - Bronze → Silver → Gold                                 │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. Run Data Quality Tests                                   │
│    - dbt test (all tests)                                   │
│    - Schema tests                                           │
│    - Custom tests                                           │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. Post-Deployment Checks                                   │
│    - Source freshness                                       │
│    - Health checks                                          │
│    - Documentation generation                               │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ 7. Send Notifications                                       │
│    - GitHub summary                                         │
│    - Slack/Email (if configured)                            │
└─────────────────────────────────────────────────────────────┘
```

**Environment Detection:**
- `main` branch → Production (`target: prod`)
- `develop` branch → Development (`target: dev`)

**Run time:** ~10-15 minutes

---

### 5. **Rollback Workflow** (`cd-rollback.yml`)

**Trigger:** Manual workflow dispatch

**Purpose:** Rollback to previous version if issues occur

**Steps:**
1. Validate rollback target (commit SHA)
2. Backup current state
3. Deploy previous version
4. Run verification tests
5. Health checks
6. Generate rollback report
7. Notify team

**Usage:**
```bash
# Go to GitHub Actions → CD - Rollback Deployment
# Select:
#   - Environment: dev/prod
#   - Commit SHA: (optional, uses previous if empty)
#   - Reason: "Description of issue"
# Click "Run workflow"
```

---

## Environment Variables

### Required Secrets (GitHub Secrets):

```yaml
# SQL Server (for CI/CD runners if testing against real DB)
SQL_SERVER_HOST: your-sql-server.database.windows.net
SQL_SERVER_PORT: 1433
SQL_DATABASE: AdventureWorks2014
SQL_USER: your-username
SQL_PASSWORD: your-secure-password

# Notifications (optional)
SLACK_WEBHOOK_URL: https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

### Set secrets:
```bash
# Go to GitHub repo → Settings → Secrets and variables → Actions
# Click "New repository secret"
```

---

## Deployment Status Badges

Add to README.md:

```markdown
![CI - DBT Test](https://github.com/your-org/dataops-project/actions/workflows/ci-dbt-test.yml/badge.svg)
![CI - Linting](https://github.com/your-org/dataops-project/actions/workflows/ci-lint.yml/badge.svg)
![CD - Deploy](https://github.com/your-org/dataops-project/actions/workflows/cd-deploy.yml/badge.svg)
```

---

## Local Testing

### Test CI workflows locally:

```bash
# Install act (GitHub Actions local runner)
brew install act  # macOS
# OR
choco install act  # Windows

# Run CI workflows locally
act pull_request

# Run specific workflow
act -W .github/workflows/ci-dbt-test.yml
```

---

## Troubleshooting

### Issue: Workflow fails on dbt deps

**Solution:**
```yaml
# Check packages.yml syntax
# Verify dbt version compatibility
```

### Issue: Tests fail in CI but pass locally

**Solution:**
```bash
# Ensure profiles.yml has CI target
# Check environment variables are set
# Verify database connectivity
```

### Issue: Deployment stuck

**Solution:**
```bash
# Check Airflow logs
# Verify Docker containers are running
# Check network connectivity
```

---

## Best Practices

1. **Always create PR** - Never push directly to main
2. **Wait for CI** - Don't merge until all checks pass
3. **Review logs** - Check CI/CD logs for warnings
4. **Test locally first** - Run `dbt test` before pushing
5. **Use conventional commits** - `feat:`, `fix:`, `docs:`, etc.
6. **Add tests for new models** - Every model needs tests
7. **Update documentation** - Keep schema.yml current
8. **Monitor deployments** - Watch GitHub Actions after merge

---

## Workflow Triggers Summary

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| ci-dbt-test.yml | PR to main/develop | Validate DBT models |
| ci-lint.yml | PR to main/develop | Enforce code quality |
| ci-pr-validation.yml | PR opened/edited | Validate PR metadata |
| cd-deploy.yml | Push to main/develop | Deploy pipeline |
| cd-rollback.yml | Manual | Rollback deployment |

---

## Monitoring & Alerts

### GitHub Actions Dashboard
- Go to: **Actions** tab in GitHub repo
- View all workflow runs
- Filter by: Branch, Status, Workflow

### Email Notifications
Configured in `default_args` of DAG and workflow files

### Slack Integration (Optional)
```python
# Add to Airflow DAG
from airflow.providers.slack.operators.slack import SlackWebhookOperator

notify_slack = SlackWebhookOperator(
    task_id='notify_slack',
    http_conn_id='slack_webhook',
    message='Pipeline completed successfully!',
)
```

---

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [DBT Documentation](https://docs.getdbt.com/)
- [SQLFluff Rules](https://docs.sqlfluff.com/en/stable/rules.html)
- [Conventional Commits](https://www.conventionalcommits.org/)
