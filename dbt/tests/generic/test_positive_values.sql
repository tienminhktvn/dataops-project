{% test positive_values(model, column_name) %}
{# =============================================================================
   CUSTOM GENERIC TEST: Positive Values
   =============================================================================
   Purpose: Verify that numeric columns contain only positive values (> 0)

   Use Cases:
   - Prices (unit_price, list_price)
   - Quantities (order_qty, stock levels)
   - Amounts (line_total, revenue)
   - Counts (total_orders, total_customers)

   Usage in schema.yml:
   columns:
     - name: unit_price
       tests:
         - positive_values

     - name: order_qty
       tests:
         - positive_values

   Test Logic:
   - Returns rows where value <= 0
   - Empty result = test PASSED (no invalid values)
   - Non-empty result = test FAILED (found invalid values)
   ============================================================================= #}

with validation as (
    select
        {{ column_name }} as value,
        count(*) as invalid_count
    from {{ model }}
    where {{ column_name }} <= 0
       or {{ column_name }} is null
    group by {{ column_name }}
)

select
    value,
    invalid_count,
    'Value must be positive (> 0)' as error_message
from validation

{% endtest %}
