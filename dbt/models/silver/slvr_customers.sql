-- =============================================================================
-- SILVER LAYER: Customers
-- =============================================================================
-- Model: slvr_customers
-- Purpose: Enrich customer data with purchase history and segmentation
-- Layer: Silver (Intermediate)
-- Materialization: TABLE
-- Dependencies: brnz_customers, slvr_sales_orders
-- =============================================================================

{{
    config(
        materialized='table',
        schema='silver',
        tags=['silver', 'customer', 'master_data'],
        post_hook=[
            "CREATE INDEX idx_slvr_customers_id ON {{ this }} (customer_id)",
            "CREATE INDEX idx_slvr_customers_segment ON {{ this }} (customer_segment)"
        ]
    )
}}

with bronze_customers as (
    select * from {{ ref('brnz_customers') }}
),

-- Aggregate customer purchase metrics from sales orders
customer_metrics as (
    select
        customer_id,

        -- Purchase counts
        count(distinct sales_order_id) as total_orders,
        count(distinct order_detail_id) as total_line_items,
        count(distinct product_id) as unique_products_purchased,

        -- Revenue metrics
        sum(line_total) as lifetime_value,
        avg(line_total) as avg_line_item_value,
        sum(order_total_due) / count(distinct sales_order_id) as avg_order_value,
        max(order_total_due) as largest_order_value,
        min(order_total_due) as smallest_order_value,

        -- Quantity metrics
        sum(order_qty) as total_units_purchased,
        avg(order_qty) as avg_units_per_line_item,

        -- Discount metrics
        sum(case when is_discounted = 1 then 1 else 0 end) as discounted_orders_count,
        avg(discount_percentage) as avg_discount_percentage,
        sum(discount_amount) as total_discount_received,

        -- Date metrics
        min(order_date) as first_order_date,
        max(order_date) as last_order_date,
        datediff(day, min(order_date), max(order_date)) as customer_tenure_days,

        -- Channel preference
        sum(case when order_channel = 'Online' then 1 else 0 end) as online_orders,
        sum(case when order_channel = 'Offline' then 1 else 0 end) as offline_orders,

        -- Order status
        sum(case when is_completed = 1 then 1 else 0 end) as completed_orders,
        sum(case when is_cancelled = 1 then 1 else 0 end) as cancelled_orders,

        -- Value tiers
        sum(case when order_value_tier = 'Enterprise' then 1 else 0 end) as enterprise_orders,
        sum(case when order_value_tier = 'High Value' then 1 else 0 end) as high_value_orders

    from {{ ref('slvr_sales_orders') }}
    group by customer_id
),

enriched as (
    select
        -- =================================================================
        -- CUSTOMER IDENTIFIERS
        -- =================================================================
        c.customer_id,
        c.account_number,

        -- =================================================================
        -- CUSTOMER PROFILE
        -- =================================================================
        c.person_id,
        c.person_type,
        c.person_type_description,
        c.customer_type,
        c.full_name,
        c.first_name,
        c.last_name,
        c.title,
        c.store_id,
        c.territory_id,

        -- =================================================================
        -- PURCHASE HISTORY METRICS
        -- =================================================================
        coalesce(m.total_orders, 0) as total_orders,
        coalesce(m.total_line_items, 0) as total_line_items,
        coalesce(m.unique_products_purchased, 0) as unique_products_purchased,
        coalesce(m.lifetime_value, 0) as lifetime_value,
        coalesce(m.avg_line_item_value, 0) as avg_line_item_value,
        coalesce(m.avg_order_value, 0) as avg_order_value,
        coalesce(m.largest_order_value, 0) as largest_order_value,
        coalesce(m.total_units_purchased, 0) as total_units_purchased,
        coalesce(m.avg_discount_percentage, 0) as avg_discount_percentage,
        coalesce(m.total_discount_received, 0) as total_discount_received,

        -- =================================================================
        -- CUSTOMER LIFECYCLE
        -- =================================================================
        m.first_order_date,
        m.last_order_date,
        coalesce(m.customer_tenure_days, 0) as customer_tenure_days,

        -- Days since last purchase
        case
            when m.last_order_date is not null
            then datediff(day, m.last_order_date, getdate())
            else null
        end as days_since_last_order,

        -- Customer age in months
        case
            when m.first_order_date is not null
            then datediff(month, m.first_order_date, getdate())
            else 0
        end as customer_age_months,

        -- =================================================================
        -- CUSTOMER BEHAVIOR ANALYSIS
        -- =================================================================
        -- Purchase frequency (orders per month)
        case
            when m.customer_tenure_days > 30
            then (cast(m.total_orders as float) / (m.customer_tenure_days / 30.0))
            else 0
        end as orders_per_month,

        -- Channel preference
        case
            when coalesce(m.online_orders, 0) > coalesce(m.offline_orders, 0) then 'Online Preferred'
            when coalesce(m.offline_orders, 0) > coalesce(m.online_orders, 0) then 'Offline Preferred'
            when coalesce(m.online_orders, 0) = coalesce(m.offline_orders, 0) and m.online_orders > 0 then 'Omnichannel'
            else 'No Orders'
        end as channel_preference,

        coalesce(m.online_orders, 0) as online_orders_count,
        coalesce(m.offline_orders, 0) as offline_orders_count,

        -- Order completion rate
        case
            when m.total_orders > 0
            then (cast(coalesce(m.completed_orders, 0) as float) / m.total_orders) * 100
            else 0
        end as order_completion_rate,

        coalesce(m.cancelled_orders, 0) as cancelled_orders_count,

        -- =================================================================
        -- CUSTOMER SEGMENTATION (RFM Analysis)
        -- =================================================================
        -- Recency: Days since last order
        case
            when m.last_order_date is null then 'Never Purchased'
            when datediff(day, m.last_order_date, getdate()) <= 30 then 'Active'
            when datediff(day, m.last_order_date, getdate()) <= 90 then 'Recent'
            when datediff(day, m.last_order_date, getdate()) <= 180 then 'Lapsed'
            else 'Dormant'
        end as recency_segment,

        -- Frequency: Number of orders
        case
            when coalesce(m.total_orders, 0) = 0 then 'No Orders'
            when m.total_orders = 1 then 'One-time'
            when m.total_orders <= 5 then 'Occasional'
            when m.total_orders <= 10 then 'Regular'
            else 'Frequent'
        end as frequency_segment,

        -- Monetary: Lifetime value
        case
            when coalesce(m.lifetime_value, 0) = 0 then 'No Value'
            when m.lifetime_value < 1000 then 'Low Value'
            when m.lifetime_value < 5000 then 'Medium Value'
            when m.lifetime_value < 20000 then 'High Value'
            else 'VIP'
        end as monetary_segment,

        -- Combined customer segment
        case
            -- VIP customers: Active + Frequent + High Value
            when datediff(day, m.last_order_date, getdate()) <= 90
                and m.total_orders > 10
                and m.lifetime_value >= 20000
            then 'VIP'

            -- Champions: Active + Frequent + Medium/High Value
            when datediff(day, m.last_order_date, getdate()) <= 30
                and m.total_orders >= 5
                and m.lifetime_value >= 5000
            then 'Champion'

            -- Loyal: Regular orders, good value
            when m.total_orders >= 5
                and m.lifetime_value >= 5000
            then 'Loyal'

            -- Potential Loyalist: Recent, growing
            when datediff(day, m.last_order_date, getdate()) <= 90
                and m.total_orders >= 2
                and m.lifetime_value >= 1000
            then 'Potential Loyalist'

            -- New: First order within 90 days
            when datediff(day, m.first_order_date, getdate()) <= 90
                and m.total_orders = 1
            then 'New Customer'

            -- At Risk: Was active, now lapsed
            when datediff(day, m.last_order_date, getdate()) between 91 and 180
                and m.total_orders >= 3
            then 'At Risk'

            -- Lost: Dormant, was previously active
            when datediff(day, m.last_order_date, getdate()) > 180
                and m.total_orders >= 3
            then 'Lost'

            -- Hibernating: Long time, few orders
            when m.total_orders <= 2
                and datediff(day, m.last_order_date, getdate()) > 180
            then 'Hibernating'

            -- Never purchased
            when m.total_orders is null
            then 'Prospect'

            else 'Other'
        end as customer_segment,

        -- =================================================================
        -- DISCOUNT BEHAVIOR
        -- =================================================================
        case
            when coalesce(m.discounted_orders_count, 0) = 0 then 'Never Discounted'
            when cast(m.discounted_orders_count as float) / m.total_orders < 0.25 then 'Rarely Discounted'
            when cast(m.discounted_orders_count as float) / m.total_orders < 0.75 then 'Sometimes Discounted'
            else 'Frequently Discounted'
        end as discount_usage_pattern,

        -- =================================================================
        -- VALUE INDICATORS
        -- =================================================================
        coalesce(m.enterprise_orders, 0) as enterprise_orders_count,
        coalesce(m.high_value_orders, 0) as high_value_orders_count,

        case
            when coalesce(m.enterprise_orders, 0) > 0 then 1
            else 0
        end as has_enterprise_orders,

        -- =================================================================
        -- METADATA
        -- =================================================================
        c.dbt_loaded_at as bronze_loaded_at,
        getdate() as silver_loaded_at

    from bronze_customers c
    left join customer_metrics m
        on c.customer_id = m.customer_id
)

select * from enriched

-- =============================================================================
-- USAGE NOTES
-- =============================================================================
--
-- This Silver layer enriches customer data with:
--
-- 1. **Purchase History**: Orders, revenue, products purchased
-- 2. **Lifecycle Metrics**: First/last order, tenure, recency
-- 3. **Behavioral Analysis**: Channel preference, order frequency
-- 4. **RFM Segmentation**: Recency, Frequency, Monetary analysis
-- 5. **Customer Segments**: VIP, Champion, Loyal, At Risk, Lost, etc.
-- 6. **Discount Behavior**: Discount usage patterns
--
-- Use this model for:
-- - Customer analytics dashboards
-- - Marketing campaign targeting
-- - Customer retention analysis
-- - Lifetime value predictions
--
-- =============================================================================
