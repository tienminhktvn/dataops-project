{% test no_future_dates(model, column_name) %}
{# =============================================================================
   CUSTOM GENERIC TEST: No Future Dates
   =============================================================================
   Purpose: Ensure date columns don't contain future dates

   Use Cases:
   - Transaction dates (order_date, ship_date, payment_date)
   - Historical events (created_at, modified_at)
   - Birth dates, registration dates

   Why This Test Matters:
   - Future dates often indicate data entry errors
   - Clock synchronization issues
   - Application bugs
   - Time zone problems

   Usage in schema.yml:
   columns:
     - name: order_date
       tests:
         - no_future_dates

     - name: ship_date
       tests:
         - no_future_dates

     - name: customer_created_at
       tests:
         - no_future_dates

   Test Logic:
   - Returns rows where date > current date
   - Uses GETDATE() for current timestamp
   - Empty result = test PASSED
   - Non-empty result = test FAILED
   ============================================================================= #}

with validation as (
    select
        {{ column_name }} as date_value,
        count(*) as invalid_count,
        getdate() as current_date
    from {{ model }}
    where {{ column_name }} > cast(getdate() as date)
    group by {{ column_name }}
)

select
    date_value,
    invalid_count,
    current_date,
    'Date cannot be in the future' as error_message,
    datediff(day, current_date, date_value) as days_in_future
from validation

{% endtest %}
