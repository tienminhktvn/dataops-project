-- =============================================================================
-- BRONZE LAYER: Products
-- =============================================================================
-- Model: brnz_products
-- Purpose: Combine Product with Category and Subcategory for complete product view
-- Layer: Bronze (Staging)
-- Materialization: VIEW
-- Dependencies:
--   - adventureworks_production.Product
--   - adventureworks_production.ProductSubcategory
--   - adventureworks_production.ProductCategory
-- =============================================================================

{{
    config(
        materialized='view',
        schema='bronze',
        tags=['bronze', 'product', 'master_data']
    )
}}

with products as (
    select
        ProductID as product_id,
        Name as product_name,
        ProductNumber as product_number,
        MakeFlag as make_flag,
        FinishedGoodsFlag as finished_goods_flag,
        Color as color,
        SafetyStockLevel as safety_stock_level,
        ReorderPoint as reorder_point,
        StandardCost as standard_cost,
        ListPrice as list_price,
        Size as size,
        Weight as weight,
        ProductSubcategoryID as product_subcategory_id,
        ProductModelID as product_model_id,
        SellStartDate as sell_start_date,
        SellEndDate as sell_end_date,
        DiscontinuedDate as discontinued_date,
        ModifiedDate as modified_date
    from {{ source('adventureworks_production', 'Product') }}
),

subcategories as (
    select
        ProductSubcategoryID as product_subcategory_id,
        ProductCategoryID as product_category_id,
        Name as subcategory_name,
        ModifiedDate as modified_date
    from {{ source('adventureworks_production', 'ProductSubcategory') }}
),

categories as (
    select
        ProductCategoryID as product_category_id,
        Name as category_name,
        ModifiedDate as modified_date
    from {{ source('adventureworks_production', 'ProductCategory') }}
),

final as (
    select
        -- Product identifiers
        p.product_id,
        p.product_number,
        p.product_name,

        -- Product categorization
        p.product_subcategory_id,
        s.subcategory_name,
        s.product_category_id,
        c.category_name,

        -- Product attributes
        p.color,
        p.size,
        p.weight,

        -- Product flags
        p.make_flag,
        case p.make_flag
            when 0 then 'Purchased'
            when 1 then 'Manufactured'
            else 'Unknown'
        end as make_description,

        p.finished_goods_flag,
        case p.finished_goods_flag
            when 0 then 'Not Salable'
            when 1 then 'Salable'
            else 'Unknown'
        end as finished_goods_description,

        -- Inventory management
        p.safety_stock_level,
        p.reorder_point,

        -- Pricing
        p.standard_cost,
        p.list_price,
        (p.list_price - p.standard_cost) as profit_margin,
        case
            when p.list_price > 0
            then ((p.list_price - p.standard_cost) / p.list_price) * 100
            else 0
        end as profit_margin_percentage,

        -- Product lifecycle dates
        p.sell_start_date,
        p.sell_end_date,
        p.discontinued_date,

        -- Product status
        case
            when p.discontinued_date is not null then 'Discontinued'
            when p.sell_end_date is not null and p.sell_end_date < getdate() then 'Ended'
            when p.sell_start_date > getdate() then 'Not Yet Available'
            else 'Active'
        end as product_status,

        -- Calculated: Days product has been sellable
        case
            when p.sell_start_date <= getdate()
            then datediff(day, p.sell_start_date, coalesce(p.sell_end_date, getdate()))
            else 0
        end as days_on_market,

        -- Foreign keys
        p.product_model_id,

        -- Metadata
        p.modified_date as product_modified_date,
        s.modified_date as subcategory_modified_date,
        c.modified_date as category_modified_date,
        getdate() as dbt_loaded_at

    from products p
    left join subcategories s
        on p.product_subcategory_id = s.product_subcategory_id
    left join categories c
        on s.product_category_id = c.product_category_id

    -- Data quality filter: Only include products with valid IDs and names
    where p.product_id > 0
        and p.product_name is not null
)

select * from final
