{% test valid_date_range(model, column_name, start_date, end_date) %}
{# =============================================================================
   CUSTOM GENERIC TEST: Valid Date Range
   =============================================================================
   Purpose: Verify dates fall within acceptable business range

   Parameters:
   - column_name: Date column to validate
   - start_date: Minimum acceptable date (format: 'YYYY-MM-DD')
   - end_date: Maximum acceptable date (format: 'YYYY-MM-DD')

   Use Cases:
   - Historical data validation (e.g., no dates before company founded)
   - Future date prevention (e.g., orders can't be in future)
   - Data migration validation (e.g., only migrate 2010-2024 data)

   Usage in schema.yml:
   columns:
     - name: order_date
       tests:
         - valid_date_range:
             start_date: '2011-01-01'
             end_date: '2024-12-31'

     - name: ship_date
       tests:
         - valid_date_range:
             start_date: '2011-01-01'
             end_date: '2025-12-31'

   Test Logic:
   - Returns rows where date < start_date OR date > end_date
   - Empty result = test PASSED
   - Non-empty result = test FAILED
   ============================================================================= #}

with validation as (
    select
        {{ column_name }} as date_value,
        count(*) as invalid_count
    from {{ model }}
    where {{ column_name }} < cast('{{ start_date }}' as date)
       or {{ column_name }} > cast('{{ end_date }}' as date)
    group by {{ column_name }}
)

select
    date_value,
    invalid_count,
    'Date must be between {{ start_date }} and {{ end_date }}' as error_message,
    '{{ start_date }}' as expected_start_date,
    '{{ end_date }}' as expected_end_date
from validation

{% endtest %}
