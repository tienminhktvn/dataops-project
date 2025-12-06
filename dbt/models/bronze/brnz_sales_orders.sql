-- =============================================================================
-- BRONZE LAYER: Sales Orders
-- =============================================================================
-- Model: brnz_sales_orders
-- Purpose: Combine SalesOrderHeader and SalesOrderDetail into denormalized view
-- Layer: Bronze (Staging)
-- Materialization: VIEW (lightweight, always fresh)
-- Dependencies:
--   - adventureworks_sales.SalesOrderHeader
--   - adventureworks_sales.SalesOrderDetail
-- =============================================================================

{{
    config(
        materialized='view',
        schema='bronze',
        tags=['bronze', 'sales', 'orders']
    )
}}

-- =============================================================================
-- TRANSFORMATION LOGIC
-- =============================================================================
-- Step 1: Extract from SalesOrderHeader (header information)
-- Step 2: Extract from SalesOrderDetail (line items)
-- Step 3: Join header + detail to create denormalized view
-- Step 4: Standardize column names (snake_case convention)
-- Step 5: Basic data type casting
-- =============================================================================

-- CTE 1: Sales Order Header
-- Extracts order-level information (dates, customer, status, etc.)
with sales_order_header as (
    select
        -- Primary Keys
        SalesOrderID as sales_order_id,

        -- Date columns
        OrderDate as order_date,
        DueDate as due_date,
        ShipDate as ship_date,

        -- Status and flags
        Status as status,
        OnlineOrderFlag as online_order_flag,

        -- Order identifiers
        SalesOrderNumber as sales_order_number,
        PurchaseOrderNumber as purchase_order_number,

        -- Foreign keys
        CustomerID as customer_id,
        SalesPersonID as sales_person_id,
        TerritoryID as territory_id,
        BillToAddressID as bill_to_address_id,
        ShipToAddressID as ship_to_address_id,
        ShipMethodID as ship_method_id,

        -- Financial columns (order level)
        SubTotal as subtotal,
        TaxAmt as tax_amount,
        Freight as freight,
        TotalDue as total_due,

        -- Metadata
        ModifiedDate as modified_date

    from {{ source('adventureworks_sales', 'SalesOrderHeader') }}
),

-- CTE 2: Sales Order Detail
-- Extracts line item information (products, quantities, prices)
sales_order_detail as (
    select
        -- Primary Keys
        SalesOrderID as sales_order_id,
        SalesOrderDetailID as order_detail_id,

        -- Product information
        ProductID as product_id,
        SpecialOfferID as special_offer_id,

        -- Quantity and pricing
        OrderQty as order_qty,
        UnitPrice as unit_price,
        UnitPriceDiscount as unit_price_discount,

        -- Calculated totals
        LineTotal as line_total,

        -- Metadata
        ModifiedDate as modified_date

    from {{ source('adventureworks_sales', 'SalesOrderDetail') }}
),

-- CTE 3: Final Join
-- Combines header + detail into single denormalized view
final as (
    select
        -- =================================================================
        -- ORDER IDENTIFIERS
        -- =================================================================
        h.sales_order_id,
        d.order_detail_id,
        h.sales_order_number,
        h.purchase_order_number,

        -- =================================================================
        -- DATE COLUMNS
        -- =================================================================
        h.order_date,
        h.due_date,
        h.ship_date,

        -- Calculated: Days between order and ship
        case
            when h.ship_date is not null
            then datediff(day, h.order_date, h.ship_date)
            else null
        end as days_to_ship,

        -- =================================================================
        -- STATUS AND FLAGS
        -- =================================================================
        h.status,
        case h.status
            when 1 then 'In process'
            when 2 then 'Approved'
            when 3 then 'Backordered'
            when 4 then 'Rejected'
            when 5 then 'Shipped'
            when 6 then 'Cancelled'
            else 'Unknown'
        end as status_description,

        h.online_order_flag,
        case
            when h.online_order_flag = 1 then 'Online'
            else 'Offline'
        end as order_channel,

        -- =================================================================
        -- FOREIGN KEYS (Relationships)
        -- =================================================================
        h.customer_id,
        h.sales_person_id,
        h.territory_id,
        h.bill_to_address_id,
        h.ship_to_address_id,
        h.ship_method_id,
        d.product_id,
        d.special_offer_id,

        -- =================================================================
        -- PRODUCT LINE ITEM (from Detail)
        -- =================================================================
        d.order_qty,
        d.unit_price,
        d.unit_price_discount,
        d.line_total,

        -- Calculated: Discount percentage
        case
            when d.unit_price > 0
            then (d.unit_price_discount / d.unit_price) * 100
            else 0
        end as discount_percentage,

        -- Calculated: Is this line item discounted?
        case
            when d.unit_price_discount > 0 then 1
            else 0
        end as is_discounted,

        -- =================================================================
        -- ORDER TOTALS (from Header)
        -- =================================================================
        h.subtotal as order_subtotal,
        h.tax_amount as order_tax_amount,
        h.freight as order_freight,
        h.total_due as order_total_due,

        -- =================================================================
        -- METADATA
        -- =================================================================
        h.modified_date as header_modified_date,
        d.modified_date as detail_modified_date,

        -- Current timestamp for tracking when record was processed
        getdate() as dbt_loaded_at

    from sales_order_header h

    -- LEFT JOIN to include headers even if they have no detail lines
    -- (though in practice, all orders should have at least one line item)
    left join sales_order_detail d
        on h.sales_order_id = d.sales_order_id

    -- =================================================================
    -- BASIC DATA QUALITY FILTERS
    -- =================================================================
    -- Filter out invalid or test data
    where 1=1
        and h.sales_order_id > 0  -- Valid order ID
        and d.order_qty > 0        -- Must have positive quantity
)

-- =============================================================================
-- FINAL SELECT
-- =============================================================================
select * from final

-- =============================================================================
-- USAGE NOTES
-- =============================================================================
--
-- This model creates a denormalized view of sales orders by joining
-- header and detail tables. Benefits:
--
-- 1. Single source for order + line item data
-- 2. Consistent column naming (snake_case)
-- 3. Basic data quality filters applied
-- 4. Calculated fields added (days_to_ship, discount_percentage, etc.)
-- 5. Human-readable status descriptions
--
-- Next Layer: Silver layer will add business logic and aggregations
--
-- =============================================================================
