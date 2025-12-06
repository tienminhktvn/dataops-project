-- =============================================================================
-- SILVER LAYER: Products
-- =============================================================================
-- Model: slvr_products
-- Purpose: Enrich product data with sales performance metrics
-- Layer: Silver (Intermediate)
-- Materialization: TABLE
-- Dependencies: brnz_products, slvr_sales_orders
-- =============================================================================

{{
    config(
        materialized='table',
        schema='silver',
        tags=['silver', 'product', 'master_data'],
        post_hook=[
            "CREATE INDEX idx_slvr_products_id ON {{ this }} (product_id)",
            "CREATE INDEX idx_slvr_products_category ON {{ this }} (category_name)",
            "CREATE INDEX idx_slvr_products_status ON {{ this }} (product_status)"
        ]
    )
}}

with bronze_products as (
    select * from {{ ref('brnz_products') }}
),

-- Aggregate product sales metrics
product_sales_metrics as (
    select
        product_id,

        -- Sales counts
        count(distinct sales_order_id) as total_orders,
        count(distinct customer_id) as unique_customers,
        count(distinct order_detail_id) as total_line_items,

        -- Quantity metrics
        sum(order_qty) as total_units_sold,
        avg(order_qty) as avg_units_per_order,
        max(order_qty) as max_units_per_order,

        -- Revenue metrics
        sum(line_total) as total_revenue,
        avg(line_total) as avg_line_item_revenue,
        max(line_total) as max_line_item_revenue,

        -- Pricing metrics
        avg(unit_price) as avg_selling_price,
        min(unit_price) as min_selling_price,
        max(unit_price) as max_selling_price,

        -- Discount metrics
        sum(case when is_discounted = 1 then 1 else 0 end) as discounted_sales_count,
        avg(case when is_discounted = 1 then discount_percentage else 0 end) as avg_discount_percentage,
        sum(discount_amount) as total_discount_given,

        -- Date metrics
        min(order_date) as first_sale_date,
        max(order_date) as last_sale_date,
        datediff(day, min(order_date), max(order_date)) as days_on_sale,

        -- Value tier distribution
        sum(case when line_item_value_category = 'High Value' then 1 else 0 end) as high_value_sales,
        sum(case when line_item_value_category = 'Medium Value' then 1 else 0 end) as medium_value_sales,
        sum(case when line_item_value_category = 'Low Value' then 1 else 0 end) as low_value_sales

    from {{ ref('slvr_sales_orders') }}
    group by product_id
),

enriched as (
    select
        -- =================================================================
        -- PRODUCT IDENTIFIERS
        -- =================================================================
        p.product_id,
        p.product_number,
        p.product_name,

        -- =================================================================
        -- PRODUCT CATEGORIZATION
        -- =================================================================
        p.category_name,
        p.subcategory_name,
        p.product_subcategory_id,
        p.product_category_id,

        -- =================================================================
        -- PRODUCT ATTRIBUTES
        -- =================================================================
        p.color,
        p.size,
        p.weight,
        p.make_flag,
        p.make_description,
        p.finished_goods_flag,
        p.finished_goods_description,

        -- =================================================================
        -- INVENTORY & PRICING
        -- =================================================================
        p.safety_stock_level,
        p.reorder_point,
        p.standard_cost,
        p.list_price,
        p.profit_margin,
        p.profit_margin_percentage,

        -- =================================================================
        -- PRODUCT LIFECYCLE
        -- =================================================================
        p.sell_start_date,
        p.sell_end_date,
        p.discontinued_date,
        p.product_status,
        p.days_on_market,

        -- =================================================================
        -- SALES PERFORMANCE METRICS
        -- =================================================================
        coalesce(m.total_orders, 0) as total_orders,
        coalesce(m.unique_customers, 0) as unique_customers,
        coalesce(m.total_line_items, 0) as total_line_items,
        coalesce(m.total_units_sold, 0) as total_units_sold,
        coalesce(m.avg_units_per_order, 0) as avg_units_per_order,
        coalesce(m.max_units_per_order, 0) as max_units_per_order,
        coalesce(m.total_revenue, 0) as total_revenue,
        coalesce(m.avg_line_item_revenue, 0) as avg_line_item_revenue,

        -- =================================================================
        -- PRICING ANALYSIS
        -- =================================================================
        coalesce(m.avg_selling_price, p.list_price) as avg_selling_price,
        coalesce(m.min_selling_price, p.list_price) as min_selling_price,
        coalesce(m.max_selling_price, p.list_price) as max_selling_price,

        -- Price variance from list price
        case
            when p.list_price > 0 and m.avg_selling_price is not null
            then ((m.avg_selling_price - p.list_price) / p.list_price) * 100
            else 0
        end as avg_price_variance_percentage,

        -- =================================================================
        -- DISCOUNT ANALYSIS
        -- =================================================================
        coalesce(m.discounted_sales_count, 0) as discounted_sales_count,
        coalesce(m.avg_discount_percentage, 0) as avg_discount_percentage,
        coalesce(m.total_discount_given, 0) as total_discount_given,

        -- Discount frequency
        case
            when m.total_line_items > 0
            then (cast(m.discounted_sales_count as float) / m.total_line_items) * 100
            else 0
        end as discount_frequency_percentage,

        -- Discount behavior classification
        case
            when coalesce(m.discounted_sales_count, 0) = 0 then 'Never Discounted'
            when cast(m.discounted_sales_count as float) / m.total_line_items < 0.25 then 'Rarely Discounted'
            when cast(m.discounted_sales_count as float) / m.total_line_items < 0.75 then 'Sometimes Discounted'
            else 'Frequently Discounted'
        end as discount_pattern,

        -- =================================================================
        -- PRODUCT PERFORMANCE CLASSIFICATION
        -- =================================================================
        -- Sales velocity (units per day)
        case
            when m.days_on_sale > 0
            then cast(m.total_units_sold as float) / m.days_on_sale
            else 0
        end as units_per_day,

        -- Revenue velocity (dollars per day)
        case
            when m.days_on_sale > 0
            then m.total_revenue / m.days_on_sale
            else 0
        end as revenue_per_day,

        -- Product popularity score (based on orders and customers)
        case
            when coalesce(m.total_orders, 0) >= 100 and coalesce(m.unique_customers, 0) >= 50 then 'Best Seller'
            when coalesce(m.total_orders, 0) >= 50 and coalesce(m.unique_customers, 0) >= 25 then 'Popular'
            when coalesce(m.total_orders, 0) >= 10 then 'Moderate'
            when coalesce(m.total_orders, 0) > 0 then 'Low Demand'
            else 'No Sales'
        end as popularity_tier,

        -- Revenue performance tier
        case
            when coalesce(m.total_revenue, 0) = 0 then 'No Revenue'
            when m.total_revenue < 10000 then 'Low Revenue'
            when m.total_revenue < 50000 then 'Medium Revenue'
            when m.total_revenue < 200000 then 'High Revenue'
            else 'Top Revenue'
        end as revenue_tier,

        -- Value mix (what type of sales does this product generate?)
        case
            when coalesce(m.high_value_sales, 0) > coalesce(m.medium_value_sales, 0) + coalesce(m.low_value_sales, 0)
            then 'Premium Product'
            when coalesce(m.low_value_sales, 0) > coalesce(m.high_value_sales, 0) + coalesce(m.medium_value_sales, 0)
            then 'Volume Product'
            else 'Balanced Product'
        end as value_mix_classification,

        -- =================================================================
        -- PROFITABILITY ANALYSIS
        -- =================================================================
        -- Total profit generated
        case
            when m.total_units_sold > 0
            then (m.total_revenue - (p.standard_cost * m.total_units_sold))
            else 0
        end as total_profit,

        -- Average profit per unit
        case
            when m.total_units_sold > 0
            then (m.total_revenue - (p.standard_cost * m.total_units_sold)) / m.total_units_sold
            else p.profit_margin
        end as avg_profit_per_unit,

        -- Actual profit margin percentage
        case
            when m.total_revenue > 0
            then ((m.total_revenue - (p.standard_cost * m.total_units_sold)) / m.total_revenue) * 100
            else p.profit_margin_percentage
        end as actual_profit_margin_percentage,

        -- =================================================================
        -- CUSTOMER ENGAGEMENT
        -- =================================================================
        -- Customer reach
        case
            when coalesce(m.unique_customers, 0) >= 100 then 'Wide Reach'
            when coalesce(m.unique_customers, 0) >= 25 then 'Moderate Reach'
            when coalesce(m.unique_customers, 0) > 0 then 'Limited Reach'
            else 'No Reach'
        end as customer_reach,

        -- Repeat purchase rate
        case
            when m.unique_customers > 0
            then (cast(m.total_orders as float) / m.unique_customers)
            else 0
        end as orders_per_customer,

        -- =================================================================
        -- LIFECYCLE STATUS
        -- =================================================================
        m.first_sale_date,
        m.last_sale_date,
        coalesce(m.days_on_sale, 0) as actual_days_on_sale,

        -- Days since last sale
        case
            when m.last_sale_date is not null
            then datediff(day, m.last_sale_date, getdate())
            else null
        end as days_since_last_sale,

        -- Product lifecycle stage
        case
            when p.product_status = 'Discontinued' then 'Discontinued'
            when p.product_status = 'Ended' then 'End of Life'
            when m.last_sale_date is null then 'Never Sold'
            when datediff(day, m.last_sale_date, getdate()) > 180 then 'Dormant'
            when datediff(day, p.sell_start_date, getdate()) <= 90 then 'New Launch'
            when m.total_orders >= 50 then 'Mature'
            else 'Growing'
        end as lifecycle_stage,

        -- =================================================================
        -- INVENTORY RISK ASSESSMENT
        -- =================================================================
        case
            when p.product_status = 'Discontinued' then 'Obsolete'
            when m.last_sale_date is null and p.product_status = 'Active' then 'Dead Stock'
            when datediff(day, m.last_sale_date, getdate()) > 180 then 'Slow Moving'
            when cast(m.total_units_sold as float) / nullif(m.days_on_sale, 0) >= 10 then 'Fast Moving'
            else 'Normal'
        end as inventory_movement_category,

        -- =================================================================
        -- METADATA
        -- =================================================================
        p.dbt_loaded_at as bronze_loaded_at,
        getdate() as silver_loaded_at

    from bronze_products p
    left join product_sales_metrics m
        on p.product_id = m.product_id
)

select * from enriched

-- =============================================================================
-- USAGE NOTES
-- =============================================================================
--
-- This Silver layer enriches product data with:
--
-- 1. **Sales Performance**: Orders, revenue, units sold
-- 2. **Pricing Analysis**: Average selling price, price variance, discounts
-- 3. **Profitability**: Actual profit, profit margins
-- 4. **Customer Engagement**: Customer reach, repeat purchase rate
-- 5. **Product Classification**: Popularity, revenue tiers, value mix
-- 6. **Lifecycle Management**: Sales velocity, lifecycle stage
-- 7. **Inventory Intelligence**: Movement category, risk assessment
--
-- Use this model for:
-- - Product performance dashboards
-- - Inventory optimization
-- - Pricing strategy analysis
-- - Product lifecycle management
-- - Category performance analysis
--
-- =============================================================================
