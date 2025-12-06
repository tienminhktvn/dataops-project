-- =============================================================================
-- GOLD LAYER: Product Performance Analytics
-- =============================================================================
-- Model: gld_product_performance
-- Purpose: Product-level KPIs for inventory and merchandising decisions
-- Layer: Gold (Marts)
-- Materialization: TABLE
-- Dependencies: slvr_products
-- =============================================================================
{{
    config(
        materialized='table',
        schema='gold',
        tags=['gold', 'product', 'analytics', 'inventory'],
        post_hook=[
            "CREATE INDEX idx_gld_products_category ON {{ this }} (category_name)",
            "CREATE INDEX idx_gld_products_status ON {{ this }} (lifecycle_stage)",
            "CREATE INDEX idx_gld_products_revenue ON {{ this }} (total_revenue)"
        ]
    )
}}

with silver_products as (
    select * from {{ ref('slvr_products') }}
),

-- STEP 1: Calculate the Base Scores and Metrics first
calculated_metrics as (
    select
        -- Identifiers
        product_id,
        product_number,
        product_name,
        category_name,
        subcategory_name,

        -- Attributes
        color,
        size,
        product_status,
        make_description,
        finished_goods_description,

        -- Pricing
        list_price,
        standard_cost,
        avg_selling_price,
        min_selling_price,
        max_selling_price,
        avg_price_variance_percentage,

        case
            when list_price >= 2000 then 'Premium'
            when list_price >= 500 then 'Mid-Range'
            when list_price >= 100 then 'Value'
            else 'Budget'
        end as price_segment,

        -- Profitability
        profit_margin,
        profit_margin_percentage,
        actual_profit_margin_percentage,
        total_profit,
        avg_profit_per_unit,

        case
            when actual_profit_margin_percentage >= 50 then 5
            when actual_profit_margin_percentage >= 40 then 4
            when actual_profit_margin_percentage >= 30 then 3
            when actual_profit_margin_percentage >= 20 then 2
            else 1
        end as profitability_rating,

        -- Sales Performance
        total_orders,
        unique_customers,
        total_units_sold,
        total_revenue,
        avg_line_item_revenue,

        -- Sales performance score (0-100) - FIXED LOGIC
        CASE
            WHEN (
                -- Revenue (max 50)
                CASE
                    WHEN total_revenue >= 200000 THEN 50
                    WHEN total_revenue >= 50000 THEN 40
                    WHEN total_revenue >= 10000 THEN 25
                    WHEN total_revenue > 0 THEN 10
                    ELSE 0
                END +
                -- Volume (max 30)
                CASE
                    WHEN total_units_sold >= 1000 THEN 30
                    WHEN total_units_sold >= 500 THEN 20
                    WHEN total_units_sold >= 100 THEN 10
                    ELSE 5
                END +
                -- Customer reach (max 20)
                CASE
                    WHEN unique_customers >= 100 THEN 20
                    WHEN unique_customers >= 50 THEN 15
                    WHEN unique_customers >= 10 THEN 8
                    ELSE 3
                END
            ) > 100 THEN 100
            ELSE (
                -- Repeat calculation
                CASE
                    WHEN total_revenue >= 200000 THEN 50
                    WHEN total_revenue >= 50000 THEN 40
                    WHEN total_revenue >= 10000 THEN 25
                    WHEN total_revenue > 0 THEN 10
                    ELSE 0
                END +
                CASE
                    WHEN total_units_sold >= 1000 THEN 30
                    WHEN total_units_sold >= 500 THEN 20
                    WHEN total_units_sold >= 100 THEN 10
                    ELSE 5
                END +
                CASE
                    WHEN unique_customers >= 100 THEN 20
                    WHEN unique_customers >= 50 THEN 15
                    WHEN unique_customers >= 10 THEN 8
                    ELSE 3
                END
            )
        END AS sales_performance_score,

        -- Classification
        popularity_tier,
        revenue_tier,
        value_mix_classification,
        lifecycle_stage,

        case
            when revenue_tier in ('Top Revenue', 'High Revenue') then 'A'
            when revenue_tier = 'Medium Revenue' then 'B'
            else 'C'
        end as abc_classification,

        -- Velocity
        units_per_day,
        revenue_per_day,
        actual_days_on_sale,
        days_since_last_sale,

        case
            when units_per_day >= 10 then 'Very Fast'
            when units_per_day >= 5 then 'Fast'
            when units_per_day >= 1 then 'Moderate'
            when units_per_day > 0 then 'Slow'
            else 'No Movement'
        end as velocity_category,

        -- Discount Analysis
        discount_frequency_percentage,
        avg_discount_percentage,
        total_discount_given,
        discount_pattern,

        case
            when total_revenue > 0
            then (total_discount_given / total_revenue) * 100
            else 0
        end as discount_impact_on_revenue,

        -- Customer Engagement
        customer_reach,
        orders_per_customer,

        case
            when orders_per_customer >= 3 then 'High Loyalty'
            when orders_per_customer >= 2 then 'Repeat Purchases'
            when orders_per_customer > 1 then 'Some Repeat'
            else 'Single Purchase'
        end as customer_loyalty_pattern,

        -- Inventory Intelligence (Raw Data)
        inventory_movement_category,
        safety_stock_level,
        reorder_point,

        -- Metadata
        first_sale_date,
        last_sale_date,
        sell_start_date,
        sell_end_date,
        getdate() as created_at
    from silver_products
),

-- STEP 2: Use the calculated metrics to build Recommendations and Health Scores
final as (
    select
        *,

        -- Stock health indicator
        case
            when inventory_movement_category = 'Dead Stock' then 'Critical'
            when inventory_movement_category = 'Obsolete' then 'Critical'
            when inventory_movement_category = 'Slow Moving' then 'Warning'
            when lifecycle_stage = 'Dormant' then 'Warning'
            when inventory_movement_category = 'Fast Moving' then 'Healthy'
            else 'Normal'
        end as stock_health,

        -- Inventory turnover estimate
        case
            when units_per_day > 0 and safety_stock_level > 0
            then safety_stock_level / units_per_day
            else null
        end as estimated_days_of_inventory,

        -- Product strategy recommendation
        case
            -- Stars: High sales, high profit
            when sales_performance_score >= 70
                and profitability_rating >= 4
            then 'Invest & Promote'

            -- Cash Cows: Good sales, moderate profit
            when sales_performance_score >= 50
                and profitability_rating >= 3
            then 'Maintain & Optimize'

            -- Question Marks: Low sales, high potential
            when sales_performance_score < 50
                and profitability_rating >= 4
                and lifecycle_stage in ('New Launch', 'Growing')
            then 'Test & Learn'

            -- Dogs: Low sales, low profit
            when sales_performance_score < 30
                and profitability_rating <= 2
            then 'Discontinue or Clearance'

            -- Declining products
            when lifecycle_stage = 'Dormant'
                or inventory_movement_category = 'Slow Moving'
            then 'Markdown or Exit'

            -- Obsolete
            when product_status = 'Discontinued'
                or inventory_movement_category = 'Obsolete'
            then 'Liquidate'

            else 'Monitor'
        end as strategic_recommendation,

        -- Pricing strategy recommendation
        case
            when avg_price_variance_percentage < -10
                and discount_frequency_percentage > 50
            then 'Reduce List Price'

            when discount_frequency_percentage > 75
            then 'Review Pricing Strategy'

            when profitability_rating <= 2
                and sales_performance_score < 30
            then 'Consider Price Increase or Discontinue'

            when sales_performance_score >= 70
                and discount_frequency_percentage < 25
            then 'Maintain Current Pricing'

            else 'Standard Pricing'
        end as pricing_recommendation,

        -- Inventory action
        case
            when inventory_movement_category = 'Dead Stock'
            then 'Clearance Sale'

            when inventory_movement_category = 'Slow Moving'
            then 'Promotional Campaign'

            when inventory_movement_category = 'Fast Moving'
                and (case when units_per_day > 0 and safety_stock_level > 0 then safety_stock_level / units_per_day else 999 end) < 7
            then 'Increase Stock Level'

            when lifecycle_stage = 'Dormant'
            then 'Stop Reordering'

            else 'Normal Operations'
        end as inventory_action,

        -- Overall product health score (0-100)
        (
            (sales_performance_score * 0.4) +  -- 40% weight on sales
            (profitability_rating * 20 * 0.3) + -- 30% weight on profit (converted to 0-100)
            (
                case
                    when lifecycle_stage in ('Mature', 'Growing') then 30
                    when lifecycle_stage = 'New Launch' then 20
                    when lifecycle_stage = 'Dormant' then 5
                    else 15
                end * 0.3  -- 30% weight on lifecycle
            )
        ) as product_health_score,

        -- Management priority (1=highest, 4=lowest)
        case
            when sales_performance_score >= 70 then 1  -- Top performers
            when inventory_movement_category in ('Dead Stock', 'Slow Moving') then 1  -- Problem products
            when lifecycle_stage = 'New Launch' then 2  -- New products need attention
            when profitability_rating <= 2 then 2  -- Low margin products
            else 3  -- Standard monitoring
        end as management_priority

    from calculated_metrics
)

select * from final

-- =============================================================================
-- USAGE NOTES
-- =============================================================================
--
-- This Gold layer provides product analytics including:
--
-- 1. **Performance Metrics**: Sales, revenue, velocity, customer reach
-- 2. **Profitability**: Margins, profit ratings, discount impact
-- 3. **Classifications**: ABC analysis, popularity tiers, lifecycle stages
-- 4. **Inventory Intelligence**: Movement category, stock health, days of inventory
-- 5. **Strategic Recommendations**: Product strategy, pricing, inventory actions
-- 6. **Priority Scoring**: Product health score, management priority
--
-- Target Users: Merchandising Team, Inventory Managers, Product Managers
-- Use Cases:
--   - Product portfolio optimization
--   - Inventory planning and forecasting
--   - Pricing strategy decisions
--   - Product lifecycle management
--   - Clearance and promotional planning
--
-- Example Queries:
--   - Top performing products:
--     SELECT * FROM gold.gld_product_performance
--     WHERE sales_performance_score >= 70
--     ORDER BY total_revenue DESC
--
--   - Products needing clearance:
--     SELECT * FROM gold.gld_product_performance
--     WHERE strategic_recommendation = 'Discontinue or Clearance'
--
--   - Fast moving items to restock:
--     SELECT * FROM gold.gld_product_performance
--     WHERE inventory_action = 'Increase Stock Level'
--
-- =============================================================================
