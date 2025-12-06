{% test valid_percentage(model, column_name, min_value=0, max_value=100) %}
{# =============================================================================
   CUSTOM GENERIC TEST: Valid Percentage
   =============================================================================
   Purpose: Verify percentage values are within valid range (typically 0-100)

   Parameters:
   - column_name: Percentage column to validate
   - min_value: Minimum acceptable value (default: 0)
   - max_value: Maximum acceptable value (default: 100)

   Use Cases:
   - Discount percentages
   - Tax rates
   - Profit margins
   - Completion rates
   - Growth rates (might need negative values)

   Usage in schema.yml:
   columns:
     - name: discount_percentage
       tests:
         - valid_percentage  # Uses default 0-100

     - name: profit_margin_percentage
       tests:
         - valid_percentage:
             min_value: -50  # Allow negative margins
             max_value: 200  # Allow >100% markup

     - name: tax_rate_percentage
       tests:
         - valid_percentage:
             min_value: 0
             max_value: 50   # Tax rates shouldn't exceed 50%

   Test Logic:
   - Returns rows where value < min_value OR value > max_value
   - Handles NULL values (considered invalid)
   - Empty result = test PASSED
   - Non-empty result = test FAILED
   ============================================================================= #}

with validation as (
    select
        {{ column_name }} as percentage_value,
        count(*) as invalid_count
    from {{ model }}
    where {{ column_name }} < {{ min_value }}
       or {{ column_name }} > {{ max_value }}
       or {{ column_name }} is null
    group by {{ column_name }}
)

select
    percentage_value,
    invalid_count,
    'Percentage must be between {{ min_value }} and {{ max_value }}' as error_message,
    {{ min_value }} as min_allowed,
    {{ max_value }} as max_allowed,
    case
        when percentage_value < {{ min_value }} then 'Below minimum'
        when percentage_value > {{ max_value }} then 'Above maximum'
        when percentage_value is null then 'NULL value'
    end as violation_type
from validation

{% endtest %}
