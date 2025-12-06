-- =============================================================================
-- GOLD LAYER: Daily Sales Summary
-- =============================================================================
-- Model: gld_sales_summary
-- Purpose: Daily aggregated sales metrics for executive dashboards
-- Layer: Gold (Marts)
-- Materialization: TABLE (optimized for BI tools)
-- Dependencies: slvr_sales_orders
-- =============================================================================

{{
    config(
        materialized='table',
        schema='gold',
        tags=['gold', 'sales', 'daily', 'dashboard'],
        post_hook=[
            "CREATE INDEX idx_gld_sales_summary_date ON {{ this }} (order_date)",
            "CREATE INDEX idx_gld_sales_summary_year_month ON {{ this }} (order_year, order_month)"
        ]
    )
}}

-- =============================================================================
-- GOLD LAYER: ANALYTICS-READY AGGREGATIONS
-- =============================================================================
-- This is the final layer that business users and BI tools connect to.
-- Data is pre-aggregated for fast query performance.
-- =============================================================================

with silver_orders as (
    select * from {{ ref('slvr_sales_orders') }}
    where is_completed = 1  -- Only include completed orders
),

daily_aggregation as (
    select
        -- =================================================================
        -- DATE DIMENSIONS
        -- =================================================================
        cast(order_date as date) as order_date,
        order_year,
        order_quarter,
        order_month,
        order_month_name,
        order_day_of_week,
        order_day_name,
        fiscal_year,
        fiscal_quarter,
        is_weekday,
        is_weekend,

        -- =================================================================
        -- ORDER COUNTS
        -- =================================================================
        count(distinct sales_order_id) as total_orders,
        count(distinct order_detail_id) as total_line_items,
        count(distinct customer_id) as unique_customers,
        count(distinct product_id) as unique_products_sold,
        count(distinct territory_id) as territories_with_sales,

        -- Average line items per order
        cast(count(distinct order_detail_id) as float) / nullif(count(distinct sales_order_id), 0) as avg_line_items_per_order,

        -- =================================================================
        -- REVENUE METRICS
        -- =================================================================
        sum(line_total) as total_revenue,
        sum(gross_amount) as total_gross_revenue,
        sum(discount_amount) as total_discounts_given,
        sum(order_tax_amount) as total_tax_collected,
        sum(order_freight) as total_freight_revenue,
        sum(order_total_due) as total_revenue_with_tax,

        -- Average metrics
        avg(line_total) as avg_line_item_value,
        sum(order_total_due) / nullif(count(distinct sales_order_id), 0) as avg_order_value,

        -- Max/Min
        max(order_total_due) as largest_order_value,
        min(order_total_due) as smallest_order_value,

        -- =================================================================
        -- QUANTITY METRICS
        -- =================================================================
        sum(order_qty) as total_units_sold,
        avg(order_qty) as avg_units_per_line_item,
        max(order_qty) as max_units_in_single_line,

        -- =================================================================
        -- DISCOUNT ANALYSIS
        -- =================================================================
        sum(case when is_discounted = 1 then 1 else 0 end) as discounted_line_items,
        sum(case when is_discounted = 0 then 1 else 0 end) as full_price_line_items,

        -- Discount penetration rate
        cast(sum(case when is_discounted = 1 then 1 else 0 end) as float) /
            nullif(count(*), 0) * 100 as discount_penetration_rate,

        -- Average discount percentage (only for discounted items)
        avg(case when is_discounted = 1 then discount_percentage else null end) as avg_discount_percentage,

        -- Discount impact on revenue
        sum(discount_amount) / nullif(sum(gross_amount), 0) * 100 as discount_impact_percentage,

        -- =================================================================
        -- CHANNEL ANALYSIS
        -- =================================================================
        sum(case when order_channel = 'Online' then line_total else 0 end) as online_revenue,
        sum(case when order_channel = 'Offline' then line_total else 0 end) as offline_revenue,
        sum(case when order_channel = 'Online' then 1 else 0 end) as online_orders_count,
        sum(case when order_channel = 'Offline' then 1 else 0 end) as offline_orders_count,

        -- Channel mix percentage
        sum(case when order_channel = 'Online' then line_total else 0 end) /
            nullif(sum(line_total), 0) * 100 as online_revenue_percentage,

        -- =================================================================
        -- ORDER VALUE TIERS
        -- =================================================================
        sum(case when order_value_tier = 'Enterprise' then 1 else 0 end) as enterprise_orders,
        sum(case when order_value_tier = 'High Value' then 1 else 0 end) as high_value_orders,
        sum(case when order_value_tier = 'Medium Value' then 1 else 0 end) as medium_value_orders,
        sum(case when order_value_tier = 'Standard' then 1 else 0 end) as standard_orders,

        sum(case when order_value_tier = 'Enterprise' then order_total_due else 0 end) as enterprise_revenue,
        sum(case when order_value_tier = 'High Value' then order_total_due else 0 end) as high_value_revenue,

        -- =================================================================
        -- SHIPPING PERFORMANCE
        -- =================================================================
        sum(case when shipping_performance = 'On Time' then 1 else 0 end) as on_time_shipments,
        sum(case when shipping_performance = 'Late' then 1 else 0 end) as late_shipments,
        sum(case when shipping_performance = 'Not Shipped' then 1 else 0 end) as unshipped_orders,

        -- On-time delivery rate
        cast(sum(case when shipping_performance = 'On Time' then 1 else 0 end) as float) /
            nullif(sum(case when shipping_performance in ('On Time', 'Late') then 1 else 0 end), 0) * 100
            as on_time_delivery_rate,

        -- Average shipping speed
        avg(case when days_to_ship is not null then days_to_ship else null end) as avg_days_to_ship,

        -- =================================================================
        -- PRODUCT MIX
        -- =================================================================
        sum(case when line_item_value_category = 'High Value' then 1 else 0 end) as high_value_line_items,
        sum(case when line_item_value_category = 'Medium Value' then 1 else 0 end) as medium_value_line_items,
        sum(case when line_item_value_category = 'Low Value' then 1 else 0 end) as low_value_line_items,

        -- =================================================================
        -- METADATA
        -- =================================================================
        count(*) as total_rows_aggregated,
        getdate() as created_at

    from silver_orders
    group by
        cast(order_date as date),
        order_year,
        order_quarter,
        order_month,
        order_month_name,
        order_day_of_week,
        order_day_name,
        fiscal_year,
        fiscal_quarter,
        is_weekday,
        is_weekend
),

-- =============================================================================
-- ADD CUMULATIVE AND COMPARISON METRICS
-- =============================================================================
with_trends as (
    select
        *,

        -- Cumulative metrics (year-to-date)
        sum(total_revenue) over (
            partition by order_year
            order by order_date
            rows between unbounded preceding and current row
        ) as ytd_revenue,

        sum(total_orders) over (
            partition by order_year
            order by order_date
            rows between unbounded preceding and current row
        ) as ytd_orders,

        -- Prior day comparison
        lag(total_revenue, 1) over (order by order_date) as prev_day_revenue,
        lag(total_orders, 1) over (order by order_date) as prev_day_orders,

        -- Week over week comparison (7 days ago)
        lag(total_revenue, 7) over (order by order_date) as prev_week_revenue,
        lag(total_orders, 7) over (order by order_date) as prev_week_orders,

        -- Moving averages
        avg(total_revenue) over (
            order by order_date
            rows between 6 preceding and current row
        ) as moving_avg_7d_revenue,

        avg(total_revenue) over (
            order by order_date
            rows between 29 preceding and current row
        ) as moving_avg_30d_revenue

    from daily_aggregation
),

-- =============================================================================
-- CALCULATE GROWTH RATES
-- =============================================================================
final as (
    select
        *,

        -- Day over day growth
        case
            when prev_day_revenue > 0
            then ((total_revenue - prev_day_revenue) / prev_day_revenue) * 100
            else null
        end as revenue_growth_dod_percentage,

        -- Week over week growth
        case
            when prev_week_revenue > 0
            then ((total_revenue - prev_week_revenue) / prev_week_revenue) * 100
            else null
        end as revenue_growth_wow_percentage,

        -- Performance vs 7-day average
        case
            when moving_avg_7d_revenue > 0
            then ((total_revenue - moving_avg_7d_revenue) / moving_avg_7d_revenue) * 100
            else null
        end as variance_from_7d_avg_percentage

    from with_trends
)

select * from final

-- =============================================================================
-- USAGE NOTES
-- =============================================================================
--
-- This Gold layer model provides daily sales summary metrics including:
--
-- 1. **Core Metrics**: Orders, revenue, customers, products
-- 2. **Discount Analysis**: Penetration rate, impact, average discount
-- 3. **Channel Performance**: Online vs Offline split
-- 4. **Order Tiers**: Enterprise, High Value, Medium, Standard
-- 5. **Shipping KPIs**: On-time delivery rate, average shipping time
-- 6. **Trend Analysis**: YTD cumulative, moving averages, growth rates
--
-- Target Users: Executives, Sales Managers, Business Analysts
-- Refresh Frequency: Daily (via Airflow DAG)
-- BI Tool Access: Direct connection for Tableau/Power BI dashboards
--
-- Example Queries:
--   - SELECT * FROM gold.gld_sales_summary WHERE order_year = 2014
--   - SELECT order_month_name, SUM(total_revenue) FROM gold.gld_sales_summary
--     WHERE order_year = 2014 GROUP BY order_month_name
--
-- =============================================================================
