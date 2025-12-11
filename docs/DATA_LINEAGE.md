# 📊 Data Lineage Documentation

> **Complete data lineage tracking from source to analytics-ready datasets**

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Source to Bronze Lineage](#source-to-bronze-lineage)
3. [Bronze to Silver Lineage](#bronze-to-silver-lineage)
4. [Silver to Gold Lineage](#silver-to-gold-lineage)
5. [Column-Level Lineage](#column-level-lineage)
6. [Transformation Details](#transformation-details)

---

## Overview

### Lineage Tracking Purpose

Data lineage trong project này giúp:

- **Traceability**: Theo dõi nguồn gốc của mỗi field trong analytics
- **Impact Analysis**: Hiểu tác động khi thay đổi source hoặc business logic
- **Data Quality**: Debug và validate data transformation
- **Compliance**: Đáp ứng yêu cầu về data governance

### Medallion Architecture

```
Source (AdventureWorks2014)
         │
         ▼
    BRONZE LAYER (Views)
    - Data cleaning
    - Standardization
         │
         ▼
    SILVER LAYER (Tables)
    - Business logic
    - Data enrichment
         │
         ▼
    GOLD LAYER (Tables)
    - Aggregations
    - Analytics-ready
```

---

## Source to Bronze Lineage

### 1. brnz_sales_orders

**Purpose**: Denormalized view of sales transactions

**Source Tables**:

- `AdventureWorks2014.Sales.SalesOrderHeader`
- `AdventureWorks2014.Sales.SalesOrderDetail`

**Transformation Logic**:

```sql
-- Join header and detail tables
SELECT
    soh.SalesOrderID as sales_order_id,
    soh.OrderDate as order_date,
    sod.SalesOrderDetailID as order_detail_id,
    sod.ProductID as product_id,
    sod.OrderQty as quantity,
    sod.UnitPrice as unit_price,
    sod.LineTotal as line_total,
    -- Calculated fields
    DATEDIFF(day, soh.OrderDate, soh.ShipDate) as days_to_ship,
    (sod.UnitPriceDiscount * 100) as discount_percentage
FROM Sales.SalesOrderHeader soh
INNER JOIN Sales.SalesOrderDetail sod
    ON soh.SalesOrderID = sod.SalesOrderID
WHERE sod.OrderQty > 0  -- Filter invalid data
```

**Key Transformations**:

- ✅ Column name standardization (PascalCase → snake_case)
- ✅ Join header and detail for denormalization
- ✅ Add calculated fields (days_to_ship, discount_percentage)
- ✅ Filter invalid records (OrderQty > 0)
- ✅ Data type conversions

**Row Count**: ~121,317 rows (one row per order line item)

---

### 2. brnz_customers

**Purpose**: Customer master data with person information

**Source Tables**:

- `AdventureWorks2014.Sales.Customer`
- `AdventureWorks2014.Person.Person`

**Transformation Logic**:

```sql
SELECT
    c.CustomerID as customer_id,
    c.AccountNumber as account_number,
    p.FirstName as first_name,
    p.MiddleName as middle_name,
    p.LastName as last_name,
    -- Concatenated full name
    CONCAT(p.FirstName, ' ', p.LastName) as full_name,
    p.EmailPromotion as email_promotion,
    c.ModifiedDate as modified_date
FROM Sales.Customer c
INNER JOIN Person.Person p
    ON c.PersonID = p.BusinessEntityID
WHERE p.FirstName IS NOT NULL
```

**Key Transformations**:

- ✅ Join customer and person tables
- ✅ Create full_name from first + last names
- ✅ Standardize column names
- ✅ Filter records with valid names

**Row Count**: ~19,820 customers

---

### 3. brnz_products

**Purpose**: Product master data with category information

**Source Tables**:

- `AdventureWorks2014.Production.Product`
- `AdventureWorks2014.Production.ProductCategory`
- `AdventureWorks2014.Production.ProductSubcategory`

**Transformation Logic**:

```sql
SELECT
    p.ProductID as product_id,
    p.Name as product_name,
    p.ProductNumber as product_number,
    psc.Name as subcategory_name,
    pc.Name as category_name,
    p.ListPrice as list_price,
    p.StandardCost as standard_cost,
    -- Calculated fields
    (p.ListPrice - p.StandardCost) as profit_margin,
    CASE
        WHEN p.ListPrice > 1000 THEN 'Premium'
        WHEN p.ListPrice > 100 THEN 'Standard'
        ELSE 'Budget'
    END as price_tier
FROM Production.Product p
LEFT JOIN Production.ProductSubcategory psc
    ON p.ProductSubcategoryID = psc.ProductSubcategoryID
LEFT JOIN Production.ProductCategory pc
    ON psc.ProductCategoryID = pc.ProductCategoryID
WHERE p.ListPrice > 0
```

**Key Transformations**:

- ✅ Join product, subcategory, and category tables
- ✅ Calculate profit_margin
- ✅ Add price_tier categorization
- ✅ Filter products with valid prices

**Row Count**: ~504 products

---

## Bronze to Silver Lineage

### 1. slvr_sales_orders

**Purpose**: Enriched sales data with business metrics

**Source Models**:

- `bronze.brnz_sales_orders` (primary)
- `bronze.brnz_customers` (for customer info)
- `bronze.brnz_products` (for product info)

**Key Business Logic**:

```sql
WITH order_enriched AS (
    SELECT
        bso.*,
        bc.full_name as customer_name,
        bc.account_number,
        bp.product_name,
        bp.category_name,
        -- Revenue calculations
        bso.line_total as revenue,
        bso.line_total * bp.profit_margin as estimated_profit,
        -- Time intelligence
        DATEPART(year, bso.order_date) as order_year,
        DATEPART(quarter, bso.order_date) as order_quarter,
        DATEPART(month, bso.order_date) as order_month,
        DATENAME(weekday, bso.order_date) as order_weekday,
        -- Categorization
        CASE
            WHEN bso.line_total >= 1000 THEN 'High Value'
            WHEN bso.line_total >= 100 THEN 'Medium Value'
            ELSE 'Low Value'
        END as order_value_category
    FROM {{ ref('brnz_sales_orders') }} bso
    LEFT JOIN {{ ref('brnz_customers') }} bc
        ON bso.customer_id = bc.customer_id
    LEFT JOIN {{ ref('brnz_products') }} bp
        ON bso.product_id = bp.product_id
)
SELECT * FROM order_enriched
```

**Transformations Applied**:

- ✅ Join with customers and products for enrichment
- ✅ Calculate estimated profit
- ✅ Add time intelligence fields (year, quarter, month, weekday)
- ✅ Categorize order value
- ✅ Preserve all bronze fields + add new calculated fields

**Row Count**: ~121,317 rows (same as bronze, enriched)

---

### 2. slvr_customers

**Purpose**: Customer analytics with RFM segmentation

**Source Models**:

- `bronze.brnz_customers` (customer master)
- `bronze.brnz_sales_orders` (for transaction history)

**Key Business Logic**:

```sql
WITH customer_metrics AS (
    SELECT
        bc.customer_id,
        bc.full_name,
        bc.account_number,
        -- RFM Metrics
        MAX(bso.order_date) as last_order_date,
        DATEDIFF(day, MAX(bso.order_date), GETDATE()) as recency_days,
        COUNT(DISTINCT bso.sales_order_id) as frequency_orders,
        SUM(bso.line_total) as monetary_total,
        -- Additional metrics
        AVG(bso.line_total) as avg_order_value,
        MIN(bso.order_date) as first_order_date,
        DATEDIFF(day, MIN(bso.order_date), MAX(bso.order_date)) as customer_lifetime_days
    FROM {{ ref('brnz_customers') }} bc
    LEFT JOIN {{ ref('brnz_sales_orders') }} bso
        ON bc.customer_id = bso.customer_id
    GROUP BY bc.customer_id, bc.full_name, bc.account_number
),
customer_rfm AS (
    SELECT
        *,
        -- RFM Scores (1-5 scale)
        NTILE(5) OVER (ORDER BY recency_days DESC) as recency_score,
        NTILE(5) OVER (ORDER BY frequency_orders) as frequency_score,
        NTILE(5) OVER (ORDER BY monetary_total) as monetary_score
    FROM customer_metrics
)
SELECT
    *,
    -- RFM Segment
    CASE
        WHEN recency_score >= 4 AND frequency_score >= 4 THEN 'Champions'
        WHEN recency_score >= 3 AND frequency_score >= 3 THEN 'Loyal Customers'
        WHEN recency_score <= 2 THEN 'At Risk'
        ELSE 'Regular'
    END as customer_segment
FROM customer_rfm
```

**Transformations Applied**:

- ✅ Calculate RFM metrics (Recency, Frequency, Monetary)
- ✅ Compute RFM scores using NTILE
- ✅ Segment customers based on RFM
- ✅ Add customer lifetime metrics
- ✅ Calculate average order value

**Row Count**: ~19,820 customers

---

### 3. slvr_products

**Purpose**: Product performance analytics

**Source Models**:

- `bronze.brnz_products` (product master)
- `bronze.brnz_sales_orders` (for sales performance)

**Key Business Logic**:

```sql
WITH product_sales AS (
    SELECT
        bp.product_id,
        bp.product_name,
        bp.category_name,
        bp.list_price,
        bp.profit_margin,
        -- Sales metrics
        COUNT(DISTINCT bso.sales_order_id) as total_orders,
        SUM(bso.quantity) as total_quantity_sold,
        SUM(bso.line_total) as total_revenue,
        AVG(bso.line_total) as avg_sale_amount,
        MAX(bso.order_date) as last_sold_date,
        -- Performance indicators
        SUM(bso.line_total) / NULLIF(SUM(bso.quantity), 0) as revenue_per_unit
    FROM {{ ref('brnz_products') }} bp
    LEFT JOIN {{ ref('brnz_sales_orders') }} bso
        ON bp.product_id = bso.product_id
    GROUP BY
        bp.product_id, bp.product_name, bp.category_name,
        bp.list_price, bp.profit_margin
)
SELECT
    *,
    -- Performance categorization
    CASE
        WHEN total_revenue >= 50000 THEN 'High Performer'
        WHEN total_revenue >= 10000 THEN 'Medium Performer'
        WHEN total_revenue > 0 THEN 'Low Performer'
        ELSE 'No Sales'
    END as performance_category
FROM product_sales
```

**Transformations Applied**:

- ✅ Aggregate sales metrics per product
- ✅ Calculate revenue per unit
- ✅ Categorize product performance
- ✅ Track last sold date
- ✅ Compute average sale amount

**Row Count**: ~504 products

---

## Silver to Gold Lineage

### 1. gld_sales_summary

**Purpose**: Daily sales metrics and KPIs

**Source Models**:

- `silver.slvr_sales_orders`

**Key Business Logic**:

```sql
SELECT
    CAST(order_date AS DATE) as date,
    order_year,
    order_quarter,
    order_month,
    -- Daily aggregations
    COUNT(DISTINCT sales_order_id) as total_orders,
    COUNT(DISTINCT customer_id) as unique_customers,
    COUNT(DISTINCT product_id) as unique_products,
    SUM(quantity) as total_quantity,
    SUM(revenue) as total_revenue,
    AVG(revenue) as avg_order_value,
    MIN(revenue) as min_order_value,
    MAX(revenue) as max_order_value,
    -- Value distribution
    SUM(CASE WHEN order_value_category = 'High Value' THEN 1 ELSE 0 END) as high_value_orders,
    SUM(CASE WHEN order_value_category = 'Medium Value' THEN 1 ELSE 0 END) as medium_value_orders,
    SUM(CASE WHEN order_value_category = 'Low Value' THEN 1 ELSE 0 END) as low_value_orders
FROM {{ ref('slvr_sales_orders') }}
GROUP BY
    CAST(order_date AS DATE),
    order_year,
    order_quarter,
    order_month
ORDER BY date
```

**Grain**: One row per date

**Row Count**: ~1,561 days

**Use Cases**:

- Daily sales dashboard
- Trend analysis
- Performance tracking
- Executive reporting

---

### 2. gld_customer_metrics

**Purpose**: Customer 360 view

**Source Models**:

- `silver.slvr_customers`
- `silver.slvr_sales_orders` (for recent activity)

**Key Business Logic**:

```sql
SELECT
    sc.customer_id,
    sc.full_name,
    sc.account_number,
    -- RFM Metrics
    sc.recency_days,
    sc.frequency_orders,
    sc.monetary_total,
    sc.customer_segment,
    -- Lifetime metrics
    sc.customer_lifetime_days,
    sc.avg_order_value,
    sc.first_order_date,
    sc.last_order_date,
    -- Recent activity (last 90 days)
    COUNT(DISTINCT CASE
        WHEN so.order_date >= DATEADD(day, -90, GETDATE())
        THEN so.sales_order_id
    END) as orders_last_90_days,
    SUM(CASE
        WHEN so.order_date >= DATEADD(day, -90, GETDATE())
        THEN so.revenue
        ELSE 0
    END) as revenue_last_90_days
FROM {{ ref('slvr_customers') }} sc
LEFT JOIN {{ ref('slvr_sales_orders') }} so
    ON sc.customer_id = so.customer_id
GROUP BY
    sc.customer_id, sc.full_name, sc.account_number,
    sc.recency_days, sc.frequency_orders, sc.monetary_total,
    sc.customer_segment, sc.customer_lifetime_days,
    sc.avg_order_value, sc.first_order_date, sc.last_order_date
```

**Grain**: One row per customer

**Row Count**: ~19,820 customers

**Use Cases**:

- Customer segmentation
- Retention analysis
- Marketing campaigns
- Churn prediction

---

### 3. gld_product_performance

**Purpose**: Product analytics and insights

**Source Models**:

- `silver.slvr_products`

**Key Business Logic**:

```sql
WITH product_rankings AS (
    SELECT
        *,
        -- Rankings
        ROW_NUMBER() OVER (
            PARTITION BY category_name
            ORDER BY total_revenue DESC
        ) as revenue_rank_in_category,
        ROW_NUMBER() OVER (
            ORDER BY total_revenue DESC
        ) as overall_revenue_rank,
        -- Percentiles
        PERCENT_RANK() OVER (
            ORDER BY total_revenue
        ) as revenue_percentile
    FROM {{ ref('slvr_products') }}
)
SELECT
    product_id,
    product_name,
    category_name,
    list_price,
    profit_margin,
    total_orders,
    total_quantity_sold,
    total_revenue,
    revenue_per_unit,
    performance_category,
    revenue_rank_in_category,
    overall_revenue_rank,
    revenue_percentile,
    -- Performance indicators
    CASE
        WHEN revenue_percentile >= 0.9 THEN 'Top 10%'
        WHEN revenue_percentile >= 0.75 THEN 'Top 25%'
        WHEN revenue_percentile >= 0.5 THEN 'Top 50%'
        ELSE 'Bottom 50%'
    END as revenue_tier
FROM product_rankings
```

**Grain**: One row per product

**Row Count**: ~504 products

**Use Cases**:

- Product portfolio analysis
- Inventory planning
- Pricing strategy
- Category performance

---

## Column-Level Lineage

### Example: total_revenue in gld_sales_summary

**Lineage Chain**:

```
Source: Sales.SalesOrderDetail.LineTotal
    │
    ├─ Type: decimal(38,6)
    └─ Business meaning: Line item total amount
              │
              ▼
Bronze: brnz_sales_orders.line_total
    │
    ├─ Transformation: Column rename (LineTotal → line_total)
    ├─ Type: decimal(38,6)
    └─ Validation: Filter WHERE OrderQty > 0
              │
              ▼
Silver: slvr_sales_orders.revenue
    │
    ├─ Transformation: Rename (line_total → revenue)
    ├─ Type: decimal(38,6)
    └─ Business logic: Join with customers and products
              │
              ▼
Gold: gld_sales_summary.total_revenue
    │
    ├─ Transformation: SUM(revenue) GROUP BY date
    ├─ Type: decimal(38,6)
    └─ Grain: Daily aggregation
```

---

## Transformation Details

### Data Quality Rules

**Bronze Layer**:

- ✅ Remove records with NULL primary keys
- ✅ Filter invalid quantities (qty > 0)
- ✅ Standardize date formats
- ✅ Convert data types consistently

**Silver Layer**:

- ✅ Apply business validation rules
- ✅ Handle NULL values with COALESCE
- ✅ Ensure referential integrity
- ✅ Add data quality flags

**Gold Layer**:

- ✅ Validate aggregation logic
- ✅ Ensure no data loss in aggregations
- ✅ Add data freshness timestamps
- ✅ Implement consistency checks

### Materialization Strategy

| Layer  | Materialization | Reason                                |
| ------ | --------------- | ------------------------------------- |
| Bronze | VIEW            | Always fresh, minimal transformation  |
| Silver | TABLE           | Complex joins, frequent queries       |
| Gold   | TABLE           | Heavy aggregations, analytics queries |

### Refresh Schedule

- **Bronze**: Real-time (view refresh on query)
- **Silver**: Daily at 1:00 AM (via Airflow)
- **Gold**: Daily at 1:00 AM (after Silver)

---

## Impact Analysis

### Changing Source Schema

If `Sales.SalesOrderDetail` schema changes:

**Impact**:

1. **Bronze**: `brnz_sales_orders` breaks
2. **Silver**: `slvr_sales_orders` fails to build
3. **Gold**: `gld_sales_summary` and `gld_customer_metrics` fail

**Mitigation**:

- Schema tests in DBT
- CI/CD validation before deployment
- Backward compatibility checks

### Changing Business Logic

If revenue calculation changes in Silver:

**Impact**:

- **Direct**: `slvr_sales_orders.revenue` column
- **Downstream**:
  - `gld_sales_summary.total_revenue`
  - `gld_customer_metrics.monetary_total`

**Mitigation**:

- Data quality tests on Silver
- Reconciliation with Bronze
- Historical data validation

---

## DBT Lineage Tools

### Generate Lineage Graph

```bash
# Generate DBT documentation with lineage
docker exec dataops-dbt dbt docs generate

# Serve documentation locally
docker exec dataops-dbt dbt docs serve --port 8001
```

### View in DBT Docs

1. Open http://localhost:8001
2. Click on any model
3. View "Lineage" tab for visual graph
4. Click "Details" for column lineage

### Lineage Commands

```bash
# List all models with dependencies
docker exec dataops-dbt dbt list --select +gld_sales_summary

# Show upstream dependencies
docker exec dataops-dbt dbt list --select +gld_sales_summary --output json

# Show downstream dependencies
docker exec dataops-dbt dbt list --select gld_sales_summary+
```

---

## Best Practices

### 1. Documentation

- Document transformation logic in model files
- Add column descriptions in schema.yml
- Maintain this lineage document

### 2. Naming Conventions

- Use descriptive column names
- Prefix layers (brnz*, slvr*, gld\_)
- Consistent naming across layers

### 3. Testing

- Test source freshness
- Validate transformations at each layer
- Monitor data quality metrics

### 4. Version Control

- Track schema changes in Git
- Document breaking changes
- Use semantic versioning

---

## Related Documentation

- **[ARCHITECTURE_DIAGRAM.md](ARCHITECTURE_DIAGRAM.md)** - System architecture
- **[TESTING_STRATEGY.md](TESTING_STRATEGY.md)** - Data quality tests
- **[DEPLOYMENT_RUNBOOK.md](DEPLOYMENT_RUNBOOK.md)** - Deployment procedures

---

**Last Updated**: December 2025  
**Version**: 1.0.0  
**Maintained By**: DataOps Project Team
