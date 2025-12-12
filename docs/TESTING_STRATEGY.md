# 🧪 Testing Strategy

> **Comprehensive testing approach for data quality, pipeline reliability, and CI/CD validation**

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Testing Philosophy](#testing-philosophy)
3. [Test Pyramid](#test-pyramid)
4. [Data Quality Tests](#data-quality-tests)
5. [Schema Tests](#schema-tests)
6. [Custom Generic Tests](#custom-generic-tests)
7. [Source Freshness Tests](#source-freshness-tests)
8. [CI/CD Testing](#cicd-testing)
9. [Test Execution](#test-execution)
10. [Test Coverage](#test-coverage)

---

## Overview

### Testing Goals

The DataOps project implements comprehensive testing to ensure:

- ✅ **Data Quality**: All data meets business requirements
- ✅ **Pipeline Reliability**: Transformations produce correct results
- ✅ **Schema Integrity**: Database structures remain consistent
- ✅ **CI/CD Validation**: Code changes don't break functionality
- ✅ **Early Detection**: Catch issues before production

### Testing Framework

**Primary Tool**: DBT (Data Build Tool)

**Test Types**:

1. Schema tests (not_null, unique, relationships, accepted_values)
2. Custom generic tests (business logic validation)
3. Source freshness tests (data recency validation)
4. Model-level tests (custom SQL queries)
5. CI/CD tests (parse, build, lint)

---

## Testing Philosophy

### Shift-Left Testing

```
Development → CI → Dev Environment → Production
     ↓         ↓         ↓              ↓
  Unit Tests  Parse   Smoke Tests  Monitoring
              Build   Integration   Alerting
              Test    E2E Tests
```

**Principle**: Catch issues as early as possible in the development cycle.

### Test Coverage Goals

| Layer     | Models | Tests   | Coverage |
| --------- | ------ | ------- | -------- |
| Bronze    | 3      | 15+     | 100%     |
| Silver    | 3      | 20+     | 100%     |
| Gold      | 3      | 15+     | 100%     |
| **Total** | **9**  | **50+** | **100%** |

### Quality Gates

**Development**:

- All models must parse successfully
- All tests must pass before commit

**CI (Pull Request)**:

- DBT parse validation
- All models must build
- All tests must pass
- Lint checks must pass

**Production**:

- Full test suite execution
- Zero test failures allowed
- Source freshness validation

---

## Test Pyramid

### Classic Test Pyramid (Adapted for Data)

```
              ┌──────────────┐
              │   E2E Tests  │ ← 5% (Airflow DAG validation)
              │   (Few)      │
              └──────────────┘
         ┌─────────────────────┐
         │ Integration Tests   │ ← 15% (Cross-model tests)
         │    (Some)           │
         └─────────────────────┘
    ┌──────────────────────────────┐
    │    Schema & Quality Tests    │ ← 80% (Column-level validation)
    │         (Many)               │
    └──────────────────────────────┘
```

### Our Implementation

| Level      | Test Type    | Count | Percentage | Example                                 |
| ---------- | ------------ | ----- | ---------- | --------------------------------------- |
| **Base**   | Schema Tests | ~40   | 80%        | `not_null`, `unique`, `positive_values` |
| **Middle** | Custom Tests | ~8    | 15%        | Date range, relationships               |
| **Top**    | Freshness    | ~6    | 5%         | Source data recency                     |
| **E2E**    | DAG Tests    | 1     | <5%        | Full pipeline execution                 |

---

## Data Quality Tests

### Quality Dimensions

**1. Completeness**

- No NULL values in required fields
- All foreign keys have matching records
- All expected records present

**2. Accuracy**

- Values fall within valid ranges
- Calculations are correct
- Dates are logical

**3. Consistency**

- Cross-model relationships maintained
- Naming conventions followed
- Data types consistent

**4. Timeliness**

- Source data is fresh
- Transformations complete on schedule
- No stale data

**5. Validity**

- Values match accepted lists
- Formats are correct
- Business rules enforced

### Implementation Matrix

| Quality Dimension | Test Type          | Example                     | Models               |
| ----------------- | ------------------ | --------------------------- | -------------------- |
| Completeness      | `not_null`         | CustomerID must exist       | Bronze, Silver, Gold |
| Completeness      | `relationships`    | CustomerID → Customer table | Bronze, Silver       |
| Accuracy          | `positive_values`  | Price > 0                   | Bronze, Silver, Gold |
| Accuracy          | `valid_date_range` | Date between 2011-2024      | Bronze, Silver       |
| Consistency       | `unique`           | ProductID is unique         | Bronze, Gold         |
| Timeliness        | `freshness`        | Updated within 30 days      | Sources              |
| Validity          | `accepted_values`  | Status in [1,2,3,4,5,6]     | Bronze               |

---

## Schema Tests

### Built-in Schema Tests

**Location**: `dbt/models/sources.yml` and `dbt/models/{layer}/schema.yml`

### 1. Not Null Tests

**Purpose**: Ensure critical columns always have values

**Example** (sources.yml):

```yaml
columns:
  - name: SalesOrderID
    description: Primary key for sales orders
    tests: [not_null]

  - name: CustomerID
    description: Foreign key to Customer table
    tests: [not_null]

  - name: OrderDate
    description: Date the order was placed
    tests: [not_null]
```

**Coverage**:

- Bronze layer: 10+ not_null tests
- Silver layer: 15+ not_null tests
- Gold layer: 10+ not_null tests

---

### 2. Unique Tests

**Purpose**: Prevent duplicate records in primary keys

**Example**:

```yaml
columns:
  - name: SalesOrderID
    tests: [not_null, unique]

  - name: CustomerID
    tests: [not_null, unique]

  - name: ProductID
    tests: [not_null, unique]
```

**Coverage**:

- Bronze layer: 3 unique tests (one per model's PK)
- Silver layer: 3 unique tests
- Gold layer: Date-based uniqueness

---

### 3. Accepted Values Tests

**Purpose**: Validate categorical data

**Example**:

```yaml
columns:
  - name: Status
    description: Order status code
    tests:
      - accepted_values:
          values: [1, 2, 3, 4, 5, 6]
```

**Business Meaning**:

```
1 = In process
2 = Approved
3 = Backordered
4 = Rejected
5 = Shipped
6 = Cancelled
```

**Coverage**:

- Status codes in orders
- Customer segments
- Product categories
- Performance tiers

---

### 4. Relationships Tests

**Purpose**: Ensure referential integrity across models

**Example**:

```yaml
columns:
  - name: customer_id
    tests:
      - relationships:
          to: ref('brnz_customers')
          field: customer_id

  - name: product_id
    tests:
      - relationships:
          to: ref('brnz_products')
          field: product_id
```

**Coverage**:

- Bronze → Source tables (implicit via SQL joins)
- Silver → Bronze models (explicit relationships)
- Gold → Silver models (explicit relationships)

---

## Custom Generic Tests

### Overview

Location: `dbt/tests/generic/`

**Purpose**: Reusable business logic validation tests

### 1. test_positive_values.sql

**Purpose**: Ensure numeric fields are positive (> 0)

**Implementation**:

```sql
{% test positive_values(model, column_name) %}
with validation as (
    select
        {{ column_name }} as value,
        count(*) as invalid_count
    from {{ model }}
    where {{ column_name }} <= 0
       or {{ column_name }} is null
    group by {{ column_name }}
)
select
    value,
    invalid_count,
    'Value must be positive (> 0)' as error_message
from validation
{% endtest %}
```

**Usage**:

```yaml
columns:
  - name: unit_price
    tests: [positive_values]

  - name: quantity
    tests: [positive_values]

  - name: line_total
    tests: [positive_values]
```

**Applied To**:

- `unit_price` in brnz_sales_orders
- `quantity` in brnz_sales_orders
- `list_price` in brnz_products
- `revenue` in slvr_sales_orders
- `total_revenue` in gld_sales_summary

---

### 2. test_valid_date_range.sql

**Purpose**: Validate dates fall within business-acceptable range

**Implementation**:

```sql
{% test valid_date_range(model, column_name, start_date, end_date) %}
with validation as (
    select
        {{ column_name }} as date_value,
        count(*) as invalid_count
    from {{ model }}
    where {{ column_name }} < cast('{{ start_date }}' as date)
       or {{ column_name }} > cast('{{ end_date }}' as date)
    group by {{ column_name }}
)
select
    date_value,
    invalid_count,
    'Date must be between {{ start_date }} and {{ end_date }}' as error_message
from validation
{% endtest %}
```

**Usage**:

```yaml
columns:
  - name: order_date
    tests:
      - valid_date_range:
          start_date: "2011-05-31"
          end_date: "2014-06-30"
```

**Business Context**:

- AdventureWorks data spans 2011-2014
- Prevents future dates (data entry errors)
- Validates historical data integrity

---

### 3. test_no_future_dates.sql

**Purpose**: Ensure dates are not in the future

**Implementation**:

```sql
{% test no_future_dates(model, column_name) %}
with validation as (
    select
        {{ column_name }} as date_value,
        count(*) as invalid_count
    from {{ model }}
    where {{ column_name }} > cast(getdate() as date)
    group by {{ column_name }}
)
select
    date_value,
    invalid_count,
    'Date cannot be in the future' as error_message
from validation
{% endtest %}
```

**Usage**:

```yaml
columns:
  - name: order_date
    tests: [no_future_dates]

  - name: last_order_date
    tests: [no_future_dates]
```

---

### 4. test_valid_percentage.sql

**Purpose**: Validate percentage values (0-100)

**Implementation**:

```sql
{% test valid_percentage(model, column_name) %}
with validation as (
    select
        {{ column_name }} as percentage_value,
        count(*) as invalid_count
    from {{ model }}
    where {{ column_name }} < 0
       or {{ column_name }} > 100
       or {{ column_name }} is null
    group by {{ column_name }}
)
select
    percentage_value,
    invalid_count,
    'Percentage must be between 0 and 100' as error_message
from validation
{% endtest %}
```

**Usage**:

```yaml
columns:
  - name: discount_percentage
    tests: [valid_percentage]
```

---

## Source Freshness Tests

### Purpose

Ensure source data is recent and up-to-date to prevent stale analytics.

### Configuration

**Location**: `dbt/models/sources.yml`

```yaml
sources:
  - name: adventureworks_sales
    database: AdventureWorks2014
    schema: Sales

    # Freshness configuration
    freshness:
      warn_after: { count: 30, period: day } # Warning after 30 days
      error_after: { count: 7300, period: day } # Error after 20 years
    loaded_at_field: ModifiedDate

    tables:
      - name: SalesOrderHeader
      - name: SalesOrderDetail
      - name: Customer
```

### Freshness Thresholds

| Source            | Warn After | Error After | Loaded At Field |
| ----------------- | ---------- | ----------- | --------------- |
| Sales tables      | 30 days    | 20 years    | ModifiedDate    |
| Production tables | 30 days    | 20 years    | ModifiedDate    |
| Person tables     | 30 days    | 20 years    | ModifiedDate    |

**Rationale**:

- **30 days warning**: Identifies potentially stale data
- **20 years error**: Prevents using extremely outdated data
- **ModifiedDate field**: Tracks when each record was last updated

### Execution

```powershell
# Check source freshness
docker exec dataops-dbt dbt source freshness --target dev --profiles-dir .

# Output:
# ✅ adventureworks_sales.SalesOrderHeader: PASS (last modified: 2 days ago)
# ✅ adventureworks_sales.SalesOrderDetail: PASS (last modified: 2 days ago)
# ⚠️  adventureworks_sales.Customer: WARN (last modified: 45 days ago)
```

### Integration with Airflow

**DAG Task**: `check_source_freshness`

```python
check_freshness = BashOperator(
    task_id='check_source_freshness',
    bash_command='cd /opt/dbt && dbt source freshness --profiles-dir .',
)
```

**Execution**: First task in daily pipeline (before models run)

---

## CI/CD Testing

### CI Pipeline Tests

**Workflow**: `.github/workflows/ci-dbt-test.yml`

### Test Stages

**Stage 1: Parse Validation**

```bash
docker exec dbt-ci dbt parse --target ci --profiles-dir .
```

- Validates SQL syntax
- Checks Jinja templating
- Verifies model references
- Detects circular dependencies

**Stage 2: Model Build**

```bash
docker exec dbt-ci dbt run --target ci --profiles-dir .
```

- Builds all bronze models
- Builds all silver models
- Builds all gold models
- Ensures transformations execute successfully

**Stage 3: Data Quality Tests**

```bash
docker exec dbt-ci dbt test --target ci --profiles-dir .
```

- Runs all schema tests
- Runs all custom generic tests
- Validates data quality
- Checks referential integrity

**Stage 4: Test Report**

- Parse test results
- Generate coverage report
- Comment on Pull Request
- Set PR status (✅ pass / ❌ fail)

### Lint Testing

**Workflow**: `.github/workflows/ci-lint.yml`

**Checks**:

1. **SQL Lint**: sqlfluff for SQL syntax and style
2. **Python Lint**: flake8 for Python code quality
3. **YAML Lint**: yamllint for YAML formatting

**Example SQL Lint Rules**:

```ini
[sqlfluff]
dialect = tsql
max_line_length = 120
indent_unit = space
indented_joins = True
indented_ctes = True
```

### PR Validation

**Workflow**: `.github/workflows/ci-pr-validation.yml`

**Checks**:

1. PR title format (conventional commits)
2. No large files (> 5MB)
3. No merge conflicts
4. Branch naming convention
5. Required files present

---

## Test Execution

### Local Testing

**Run All Tests**:

```powershell
# Development environment
docker exec dataops-dbt dbt test --target dev --profiles-dir .

# Expected output:
# Completed successfully
# Done. PASS=50 WARN=0 ERROR=0 SKIP=0 TOTAL=50
```

**Run Specific Model Tests**:

```powershell
# Test one model
docker exec dataops-dbt dbt test --select brnz_sales_orders --target dev --profiles-dir .

# Test model and dependencies
docker exec dataops-dbt dbt test --select +slvr_sales_orders --target dev --profiles-dir .

# Test model and downstream
docker exec dataops-dbt dbt test --select slvr_sales_orders+ --target dev --profiles-dir .
```

**Run Test by Type**:

```powershell
# Schema tests only
docker exec dataops-dbt dbt test --select test_type:schema --target dev --profiles-dir .

# Custom generic tests only
docker exec dataops-dbt dbt test --select test_type:generic --target dev --profiles-dir .

# Relationship tests only
docker exec dataops-dbt dbt test --select test_type:relationships --target dev --profiles-dir .
```

**Run Tests for Specific Layer**:

```powershell
# Bronze layer tests
docker exec dataops-dbt dbt test --select bronze --target dev --profiles-dir .

# Silver layer tests
docker exec dataops-dbt dbt test --select silver --target dev --profiles-dir .

# Gold layer tests
docker exec dataops-dbt dbt test --select gold --target dev --profiles-dir .
```

### CI Testing

**Triggered By**:

- Opening Pull Request
- Pushing to open PR

**Automatic Execution**:

- GitHub Actions runs all tests
- Results commented on PR
- PR status updated (✅/❌)

**Example PR Comment**:

```
✅ DBT Pipeline Tests Passed

📊 Test Results:
- Total Tests: 50
- Passed: 50 ✅
- Failed: 0
- Warnings: 0

🏗️ Models Built:
- Bronze: 3 models
- Silver: 3 models
- Gold: 3 models

🎯 Coverage: 100%

✨ All checks passed successfully!
```

### Production Testing

**Triggered By**:

- Push to `main` branch
- CD pipeline deployment

**Execution**:

```bash
# Part of deployment workflow
docker exec dataops-dbt dbt test --target prod --profiles-dir .
```

**Failure Handling**:

- Deployment marked as failed
- Slack notification sent
- Rollback may be triggered

---

## Test Coverage

### Coverage by Layer

**Bronze Layer** (3 models):

| Model             | Tests | Types                                                                      |
| ----------------- | ----- | -------------------------------------------------------------------------- |
| brnz_sales_orders | 15    | not_null (6), positive_values (3), valid_date_range (2), relationships (4) |
| brnz_customers    | 8     | not_null (4), unique (1), relationships (3)                                |
| brnz_products     | 10    | not_null (5), unique (1), positive_values (2), relationships (2)           |

**Silver Layer** (3 models):

| Model             | Tests | Types                                                            |
| ----------------- | ----- | ---------------------------------------------------------------- |
| slvr_sales_orders | 18    | not_null (8), positive_values (4), relationships (6)             |
| slvr_customers    | 12    | not_null (6), unique (1), no_future_dates (2), relationships (3) |
| slvr_products     | 14    | not_null (7), positive_values (3), relationships (4)             |

**Gold Layer** (3 models):

| Model                   | Tests | Types                                                   |
| ----------------------- | ----- | ------------------------------------------------------- |
| gld_sales_summary       | 10    | not_null (5), positive_values (3), valid_date_range (2) |
| gld_customer_metrics    | 8     | not_null (4), positive_values (2), no_future_dates (2)  |
| gld_product_performance | 9     | not_null (5), positive_values (2), valid_percentage (2) |

### Coverage Report

```
Total Models: 9
Total Tests: 104 (schema + custom)
Coverage: 100%

Test Type Distribution:
- not_null: 50 (48%)
- positive_values: 19 (18%)
- unique: 9 (9%)
- relationships: 19 (18%)
- valid_date_range: 4 (4%)
- no_future_dates: 2 (2%)
- valid_percentage: 1 (1%)
```

### Coverage Goals

**Current**:

- ✅ 100% model coverage (all models tested)
- ✅ 100% critical column coverage
- ✅ Source freshness validation

**Future Improvements**:

1. Add data profiling tests (min/max/avg)
2. Add distribution tests (outlier detection)
3. Add trend analysis tests (anomaly detection)
4. Add cross-model consistency checks

---

## Test Results Interpretation

### Successful Test Run

```
$ docker exec dataops-dbt dbt test --target dev --profiles-dir .

Running with dbt=1.8.7
Found 9 models, 50 tests, 0 seeds, 0 analyses, 6 sources

Concurrency: 4 threads (target='dev')

1 of 50 START test not_null_brnz_sales_orders_sales_order_id .............. [RUN]
1 of 50 PASS not_null_brnz_sales_orders_sales_order_id .................... [PASS in 0.12s]
2 of 50 START test unique_brnz_customers_customer_id ....................... [RUN]
2 of 50 PASS unique_brnz_customers_customer_id ............................ [PASS in 0.15s]
...
50 of 50 START test positive_values_gld_sales_summary_total_revenue ....... [RUN]
50 of 50 PASS positive_values_gld_sales_summary_total_revenue ............. [PASS in 0.18s]

Completed successfully

Done. PASS=50 WARN=0 ERROR=0 SKIP=0 TOTAL=50
```

### Failed Test Run

```
$ docker exec dataops-dbt dbt test --target dev --profiles-dir .

Running with dbt=1.8.7
Found 9 models, 50 tests

1 of 50 START test not_null_brnz_sales_orders_customer_id ................. [RUN]
1 of 50 FAIL 5 not_null_brnz_sales_orders_customer_id ..................... [FAIL 5 in 0.12s]
2 of 50 START test positive_values_brnz_sales_orders_unit_price ........... [RUN]
2 of 50 FAIL 10 positive_values_brnz_sales_orders_unit_price .............. [FAIL 10 in 0.15s]
...

Completed with 2 errors

Done. PASS=48 WARN=0 ERROR=2 SKIP=0 TOTAL=50

Failure Details:
- not_null_brnz_sales_orders_customer_id: 5 rows with NULL customer_id
- positive_values_brnz_sales_orders_unit_price: 10 rows with unit_price <= 0
```

**Action**: Fix source data or add filtering logic in bronze models.

---

## Best Practices

### 1. Test Early, Test Often

```
Write Model → Add Tests → Run Tests → Commit
```

**Never commit untested models**

### 2. Layer-Specific Testing

**Bronze**:

- Focus on data type validation
- Source data integrity
- Basic constraints

**Silver**:

- Business logic validation
- Cross-model relationships
- Calculated fields accuracy

**Gold**:

- Aggregation correctness
- Final metric validation
- Executive-level accuracy

### 3. Test Naming Convention

```yaml
# Good
test_name: positive_values_brnz_sales_orders_unit_price

# Bad
test_name: test1
```

### 4. Test Documentation

```yaml
columns:
  - name: unit_price
    description: Selling price per unit in USD
    tests:
      - positive_values # Prices must be > 0
      - valid_percentage # Discounts must be 0-100%
```

### 5. Fail Fast

Configure DBT to fail on first error in CI:

```yaml
# dbt_project.yml
flags:
  warn_error: true # Treat warnings as errors
```

---

## Related Documentation

- **[ARCHITECTURE_DIAGRAM.md](ARCHITECTURE_DIAGRAM.md)** - System architecture
- **[DATA_LINEAGE.md](DATA_LINEAGE.md)** - Data transformation lineage
- **[DEPLOYMENT_RUNBOOK.md](DEPLOYMENT_RUNBOOK.md)** - Deployment procedures
- **[MULTI_ENVIRONMENT_SETUP.md](MULTI_ENVIRONMENT_SETUP.md)** - Environment configuration

---

**Last Updated**: December 2025  
**Version**: 1.0.0  
**Maintained By**: DataOps Project Team
