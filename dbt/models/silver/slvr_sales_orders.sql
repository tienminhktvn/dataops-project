-- =============================================================================
-- SILVER LAYER: Sales Orders
-- =============================================================================
-- Model: slvr_sales_orders
-- Purpose: Apply business logic and enrich sales order data
-- Layer: Silver (Intermediate)
-- Materialization: TABLE (better performance for downstream joins)
-- Dependencies: brnz_sales_orders
-- =============================================================================

{{
    config(
        materialized='table',
        schema='silver',
        tags=['silver', 'sales', 'orders'],
        post_hook=[
            "CREATE INDEX idx_slvr_sales_orders_customer ON {{ this }} (customer_id)",
            "CREATE INDEX idx_slvr_sales_orders_product ON {{ this }} (product_id)",
            "CREATE INDEX idx_slvr_sales_orders_date ON {{ this }} (order_date)"
        ]
    )
}}

-- =============================================================================
-- BUSINESS LOGIC TRANSFORMATIONS
-- =============================================================================
-- This layer applies business rules and enrichment:
-- 1. Revenue categorization (High/Medium/Low value orders)
-- 2. Customer segment classification
-- 3. Product performance metrics
-- 4. Time-based analysis (day of week, quarter, year)
-- 5. Discount strategy analysis
-- 6. Shipping performance metrics
-- =============================================================================

with bronze_orders as (
    select * from {{ ref('brnz_sales_orders') }}
),

enriched as (
    select
        -- =================================================================
        -- PRIMARY KEYS (Preserved from Bronze)
        -- =================================================================
        sales_order_id,
        order_detail_id,
        sales_order_number,

        -- =================================================================
        -- DATE DIMENSIONS
        -- =================================================================
        order_date,
        due_date,
        ship_date,
        days_to_ship,

        -- Extract date components for analysis
        year(order_date) as order_year,
        datepart(quarter, order_date) as order_quarter,
        month(order_date) as order_month,
        day(order_date) as order_day,
        datepart(weekday, order_date) as order_day_of_week,
        datename(weekday, order_date) as order_day_name,
        datename(month, order_date) as order_month_name,

        -- Fiscal periods (AdventureWorks fiscal year starts July 1)
        case
            when month(order_date) >= 7 then year(order_date) + 1
            else year(order_date)
        end as fiscal_year,

        case
            when month(order_date) in (7, 8, 9) then 1
            when month(order_date) in (10, 11, 12) then 2
            when month(order_date) in (1, 2, 3) then 3
            when month(order_date) in (4, 5, 6) then 4
        end as fiscal_quarter,

        -- Business day flags
        case
            when datepart(weekday, order_date) in (1, 7) then 0  -- Weekend
            else 1  -- Weekday
        end as is_weekday,

        case
            when datepart(weekday, order_date) in (1, 7) then 1
            else 0
        end as is_weekend,

        -- =================================================================
        -- ORDER STATUS & CHANNEL
        -- =================================================================
        status,
        status_description,
        online_order_flag,
        order_channel,

        -- Channel refinement
        case
            when order_channel = 'Online' and sales_person_id is null then 'Direct Online'
            when order_channel = 'Online' and sales_person_id is not null then 'Assisted Online'
            when order_channel = 'Offline' and sales_person_id is not null then 'Sales Person'
            when order_channel = 'Offline' and sales_person_id is null then 'Walk-in'
            else 'Unknown'
        end as order_channel_detail,

        -- =================================================================
        -- FOREIGN KEYS
        -- =================================================================
        customer_id,
        sales_person_id,
        territory_id,
        product_id,

        -- =================================================================
        -- PRODUCT LINE ITEM METRICS
        -- =================================================================
        order_qty,
        unit_price,
        unit_price_discount,
        line_total,
        discount_percentage,
        is_discounted,

        -- Calculated: Gross amount before discount
        unit_price * order_qty as gross_amount,

        -- Calculated: Total discount in dollars
        (unit_price * order_qty) - line_total as discount_amount,

        -- Calculated: Effective unit price (after discount)
        case
            when order_qty > 0 then line_total / order_qty
            else 0
        end as effective_unit_price,

        -- Revenue categorization per line item
        case
            when line_total >= 1000 then 'High Value'
            when line_total >= 500 then 'Medium Value'
            when line_total >= 100 then 'Low Value'
            else 'Minimal Value'
        end as line_item_value_category,

        -- Discount strategy classification
        case
            when discount_percentage = 0 then 'No Discount'
            when discount_percentage < 5 then 'Minimal Discount'
            when discount_percentage < 15 then 'Standard Discount'
            when discount_percentage < 30 then 'High Discount'
            else 'Clearance'
        end as discount_strategy,

        -- =================================================================
        -- ORDER TOTALS (Order Level Metrics)
        -- =================================================================
        order_subtotal,
        order_tax_amount,
        order_freight,
        order_total_due,

        -- Calculated: Tax rate percentage
        case
            when order_subtotal > 0
            then (order_tax_amount / order_subtotal) * 100
            else 0
        end as tax_rate_percentage,

        -- Calculated: Shipping as percentage of subtotal
        case
            when order_subtotal > 0
            then (order_freight / order_subtotal) * 100
            else 0
        end as freight_percentage,

        -- =================================================================
        -- BUSINESS RULE: Order Value Classification
        -- =================================================================
        -- Classify entire order by total value
        case
            when order_total_due >= 5000 then 'Enterprise'
            when order_total_due >= 2000 then 'High Value'
            when order_total_due >= 500 then 'Medium Value'
            else 'Standard'
        end as order_value_tier,

        -- =================================================================
        -- BUSINESS RULE: Shipping Performance Analysis
        -- =================================================================
        -- Analyze shipping performance
        case
            when ship_date is null then 'Not Shipped'
            when ship_date <= due_date then 'On Time'
            when ship_date > due_date then 'Late'
            else 'Unknown'
        end as shipping_performance,

        -- Calculate delay in days (if late)
        case
            when ship_date > due_date
            then datediff(day, due_date, ship_date)
            else 0
        end as days_late,

        -- Shipping speed category
        case
            when days_to_ship is null then 'Not Shipped'
            when days_to_ship = 0 then 'Same Day'
            when days_to_ship <= 1 then 'Next Day'
            when days_to_ship <= 3 then 'Express'
            when days_to_ship <= 7 then 'Standard'
            else 'Slow'
        end as shipping_speed_category,

        -- =================================================================
        -- BUSINESS RULE: Quantity Analysis
        -- =================================================================
        -- Bulk order indicator
        case
            when order_qty >= 100 then 'Bulk Order'
            when order_qty >= 20 then 'Large Order'
            when order_qty >= 5 then 'Medium Order'
            else 'Small Order'
        end as order_size_category,

        -- =================================================================
        -- DATA QUALITY FLAGS
        -- =================================================================
        -- Flag potential data quality issues
        case
            when unit_price <= 0 then 1
            when order_qty <= 0 then 1
            when line_total <= 0 then 1
            when order_total_due <= 0 then 1
            else 0
        end as has_data_quality_issue,

        -- Flag suspicious discounts
        case
            when discount_percentage > 50 then 1
            else 0
        end as has_high_discount_flag,

        -- Flag incomplete orders
        case
            when status in (4, 6) then 1  -- Rejected or Cancelled
            else 0
        end as is_cancelled,

        case
            when status = 5 and ship_date is not null then 1
            else 0
        end as is_completed,

        -- =================================================================
        -- METADATA
        -- =================================================================
        dbt_loaded_at as bronze_loaded_at,
        getdate() as silver_loaded_at

    from bronze_orders

    -- Apply data quality filters
    where 1=1
        and order_qty > 0
        and unit_price >= 0
        and line_total >= 0
),

-- =============================================================================
-- WINDOW FUNCTIONS: Add ranking and cumulative metrics
-- =============================================================================
final as (
    select
        *,

        -- Rank products by revenue within each order
        row_number() over (
            partition by sales_order_id
            order by line_total desc
        ) as product_rank_in_order,

        -- Calculate running total within each order
        sum(line_total) over (
            partition by sales_order_id
            order by order_detail_id
            rows between unbounded preceding and current row
        ) as cumulative_order_total,

        -- Calculate percentage of order total
        case
            when sum(line_total) over (partition by sales_order_id) > 0
            then (line_total / sum(line_total) over (partition by sales_order_id)) * 100
            else 0
        end as percentage_of_order_total

    from enriched
)

select * from final

-- =============================================================================
-- USAGE NOTES
-- =============================================================================
--
-- This Silver layer model adds significant business value:
--
-- 1. **Time Intelligence**: Date components, fiscal periods, day of week
-- 2. **Categorization**: Order value tiers, discount strategies, shipping speed
-- 3. **Performance Metrics**: Shipping performance, order completion status
-- 4. **Data Quality**: Flags for suspicious or incomplete data
-- 5. **Advanced Analytics**: Window functions for ranking and cumulative totals
--
-- Downstream models (Gold layer) will aggregate this enriched data for
-- executive dashboards and analytics.
--
-- Performance Note: Materialized as TABLE with indexes on commonly-joined columns
-- =============================================================================
