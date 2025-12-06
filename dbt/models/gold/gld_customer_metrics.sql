-- =============================================================================
-- GOLD LAYER: Customer Analytics Mart
-- =============================================================================
-- Model: gld_customer_metrics
-- Purpose: Customer-level metrics for marketing and retention analysis
-- Layer: Gold (Marts)
-- Materialization: TABLE
-- Dependencies: slvr_customers
-- =============================================================================

{{
    config(
        materialized='table',
        schema='gold',
        tags=['gold', 'customer', 'analytics', 'dashboard'],
        post_hook=[
            "CREATE INDEX idx_gld_customers_segment ON {{ this }} (customer_segment)",
            "CREATE INDEX idx_gld_customers_ltv ON {{ this }} (lifetime_value)"
        ]
    )
}}

-- =============================================================================
-- CUSTOMER ANALYTICS MART
-- =============================================================================
-- Pre-aggregated customer metrics for marketing dashboards and analysis
-- =============================================================================

with silver_customers as (
    select * from {{ ref('slvr_customers') }}
),

final as (
    select
        -- =================================================================
        -- CUSTOMER IDENTIFIERS
        -- =================================================================
        customer_id,
        account_number,
        full_name,
        customer_type,
        person_type_description,

        -- =================================================================
        -- SEGMENTATION
        -- =================================================================
        customer_segment,
        recency_segment,
        frequency_segment,
        monetary_segment,
        channel_preference,

        -- =================================================================
        -- PURCHASE BEHAVIOR
        -- =================================================================
        total_orders,
        total_line_items,
        unique_products_purchased,
        total_units_purchased,
        orders_per_month,

        -- Product diversity score (0-100)
        case
            when total_orders > 0
            then (cast(unique_products_purchased as float) / total_line_items) * 100
            else 0
        end as product_diversity_score,

        -- =================================================================
        -- REVENUE METRICS
        -- =================================================================
        lifetime_value,
        avg_order_value,
        avg_line_item_value,
        largest_order_value,

        -- Customer value rating
        case
            when lifetime_value >= 50000 then 5  -- Platinum
            when lifetime_value >= 20000 then 4  -- Gold
            when lifetime_value >= 5000 then 3   -- Silver
            when lifetime_value >= 1000 then 2   -- Bronze
            else 1                                -- Basic
        end as customer_value_rating,

        -- =================================================================
        -- LIFECYCLE METRICS
        -- =================================================================
        first_order_date,
        last_order_date,
        customer_age_months,
        customer_tenure_days,
        days_since_last_order,

        -- Lifetime value per month (acquisition efficiency)
        case
            when customer_age_months > 0
            then lifetime_value / customer_age_months
            else 0
        end as ltv_per_month,

        -- =================================================================
        -- ENGAGEMENT INDICATORS
        -- =================================================================
        order_completion_rate,
        cancelled_orders_count,
        online_orders_count,
        offline_orders_count,

        -- Engagement score (0-100)
        CASE
            WHEN ISNULL(total_orders, 0) = 0 THEN 0
            ELSE
                CASE
                    -- Calculate the raw score first
                    WHEN (
                        -- Recency (max 40)
                        CASE
                            WHEN days_since_last_order <= 30 THEN 40
                            WHEN days_since_last_order <= 90 THEN 30
                            WHEN days_since_last_order <= 180 THEN 15
                            ELSE 5
                        END +
                        -- Frequency (max 30)
                        CASE
                            WHEN orders_per_month >= 2 THEN 30
                            WHEN orders_per_month >= 1 THEN 20
                            WHEN orders_per_month >= 0.5 THEN 10
                            ELSE 5
                        END +
                        -- Completion Rate (max 30) - Handle NULLs here
                        (ISNULL(order_completion_rate, 0) * 0.3)
                    ) > 100 THEN 100 -- Cap at 100 manually
                    ELSE (
                        -- Repeat calculation for the "ELSE" condition
                        CASE
                            WHEN days_since_last_order <= 30 THEN 40
                            WHEN days_since_last_order <= 90 THEN 30
                            WHEN days_since_last_order <= 180 THEN 15
                            ELSE 5
                        END +
                        CASE
                            WHEN orders_per_month >= 2 THEN 30
                            WHEN orders_per_month >= 1 THEN 20
                            WHEN orders_per_month >= 0.5 THEN 10
                            ELSE 5
                        END +
                        (ISNULL(order_completion_rate, 0) * 0.3)
                    )
                END
        END AS engagement_score,
        -- =================================================================
        -- DISCOUNT BEHAVIOR
        -- =================================================================
        avg_discount_percentage,
        total_discount_received,
        discount_usage_pattern,

        -- Discount dependency score (0-100)
        case
            when total_orders > 0
            then (total_discount_received / nullif(lifetime_value, 0)) * 100
            else 0
        end as discount_dependency_percentage,

        -- =================================================================
        -- RISK INDICATORS
        -- =================================================================
        -- Churn risk score (0-100, higher = more risk)
        case
            when customer_segment = 'Lost' then 90
            when customer_segment = 'At Risk' then 70
            when customer_segment = 'Hibernating' then 60
            when days_since_last_order > 180 then 50
            when days_since_last_order > 90 then 30
            when order_completion_rate < 50 then 40
            else 10
        end as churn_risk_score,

        -- Reactivation potential (for lapsed customers)
        case
            when customer_segment in ('At Risk', 'Lost', 'Hibernating')
                and lifetime_value >= 5000
                and total_orders >= 5
            then 'High Potential'
            when customer_segment in ('At Risk', 'Lost')
                and total_orders >= 3
            then 'Medium Potential'
            when customer_segment in ('Hibernating', 'Lost')
            then 'Low Potential'
            else 'Not Applicable'
        end as reactivation_potential,

        -- =================================================================
        -- GROWTH OPPORTUNITY
        -- =================================================================
        -- Upsell opportunity score
        case
            when customer_segment in ('Champion', 'Loyal')
                and avg_order_value < 1000
            then 'High Upsell Opportunity'
            when customer_segment = 'Potential Loyalist'
                and avg_order_value < 500
            then 'Medium Upsell Opportunity'
            when total_orders >= 3
                and avg_order_value < largest_order_value * 0.5
            then 'Upsell Potential'
            else 'Standard'
        end as upsell_opportunity,

        -- Cross-sell opportunity
        case
            when unique_products_purchased < 3
                and total_orders >= 3
            then 'High Cross-sell Opportunity'
            when unique_products_purchased < 5
                and total_orders >= 5
            then 'Medium Cross-sell Opportunity'
            else 'Standard'
        end as crosssell_opportunity,

        -- =================================================================
        -- ACTIONABLE INSIGHTS
        -- =================================================================
        -- Recommended next action
        case
            when customer_segment = 'VIP' then 'VIP Retention Program'
            when customer_segment = 'Champion' then 'Loyalty Rewards'
            when customer_segment = 'Loyal' then 'Upsell Campaign'
            when customer_segment = 'Potential Loyalist' then 'Nurture Campaign'
            when customer_segment = 'New Customer' then 'Onboarding Program'
            when customer_segment = 'At Risk' then 'Win-back Campaign'
            when customer_segment = 'Lost' then 'Reactivation Campaign'
            when customer_segment = 'Hibernating' then 'Re-engagement Email'
            when customer_segment = 'Prospect' then 'Acquisition Campaign'
            else 'Review'
        end as recommended_action,

        -- Marketing priority level
        case
            when customer_segment in ('VIP', 'Champion') then 1
            when customer_segment in ('Loyal', 'At Risk') then 2
            when customer_segment in ('Potential Loyalist', 'Lost') then 3
            else 4
        end as marketing_priority,

        -- =================================================================
        -- METADATA
        -- =================================================================
        getdate() as created_at

    from silver_customers
)

select * from final

-- =============================================================================
-- USAGE NOTES
-- =============================================================================
--
-- This Gold layer provides customer analytics including:
--
-- 1. **Segmentation**: RFM segments, customer types, channel preference
-- 2. **Value Metrics**: Lifetime value, customer value rating, LTV per month
-- 3. **Engagement**: Engagement score, order frequency, completion rate
-- 4. **Risk Analysis**: Churn risk score, reactivation potential
-- 5. **Opportunities**: Upsell and cross-sell opportunities
-- 6. **Actionable Insights**: Recommended actions, marketing priority
--
-- Target Users: Marketing Team, Customer Success, Sales Management
-- Use Cases:
--   - Customer retention strategies
--   - Targeted marketing campaigns
--   - VIP customer management
--   - Win-back campaigns for at-risk customers
--
-- Example Queries:
--   - High-value at-risk customers:
--     SELECT * FROM gold.gld_customer_metrics
--     WHERE customer_segment = 'At Risk' AND lifetime_value > 10000
--
--   - VIP customers for retention program:
--     SELECT * FROM gold.gld_customer_metrics
--     WHERE customer_segment = 'VIP'
--     ORDER BY lifetime_value DESC
--
-- =============================================================================
