-- =============================================================================
-- BRONZE LAYER: Customers
-- =============================================================================
-- Model: brnz_customers
-- Purpose: Combine Customer and Person tables for complete customer view
-- Layer: Bronze (Staging)
-- Materialization: VIEW
-- Dependencies:
--   - adventureworks_sales.Customer
--   - adventureworks_person.Person
-- =============================================================================

{{
    config(
        materialized='view',
        schema='bronze',
        tags=['bronze', 'customer', 'master_data']
    )
}}

with customers as (
    select
        CustomerID as customer_id,
        PersonID as person_id,
        StoreID as store_id,
        TerritoryID as territory_id,
        AccountNumber as account_number,
        ModifiedDate as modified_date
    from {{ source('adventureworks_sales', 'Customer') }}
),

persons as (
    select
        BusinessEntityID as person_id,
        PersonType as person_type,
        Title as title,
        FirstName as first_name,
        MiddleName as middle_name,
        LastName as last_name,
        Suffix as suffix,
        ModifiedDate as modified_date
    from {{ source('adventureworks_person', 'Person') }}
),

final as (
    select
        -- Customer identifiers
        c.customer_id,
        c.account_number,

        -- Person details
        c.person_id,
        p.person_type,
        case p.person_type
            when 'SC' then 'Store Contact'
            when 'IN' then 'Individual Customer'
            when 'SP' then 'Sales Person'
            when 'EM' then 'Employee'
            when 'VC' then 'Vendor Contact'
            when 'GC' then 'General Contact'
            else 'Unknown'
        end as person_type_description,

        -- Name components
        p.title,
        p.first_name,
        p.middle_name,
        p.last_name,
        p.suffix,

        -- Constructed full name
        concat_ws(' ',
            p.title,
            p.first_name,
            p.middle_name,
            p.last_name,
            p.suffix
        ) as full_name,

        -- Foreign keys
        c.store_id,
        c.territory_id,

        -- Customer type indicator
        case
            when c.store_id is not null then 'Business'
            when c.person_id is not null then 'Individual'
            else 'Unknown'
        end as customer_type,

        -- Metadata
        c.modified_date as customer_modified_date,
        p.modified_date as person_modified_date,
        getdate() as dbt_loaded_at

    from customers c
    left join persons p
        on c.person_id = p.person_id
)

select * from final
