from datetime import timedelta

from airflow.models import Variable
from utils.slack_notifications import (
    send_failure_notification,
)

# Default arguments for all tasks
DEFAULT_ARGS = {
    "owner": "data-engineering-team",
    "depends_on_past": False,
    "retries": 3,
    "retry_delay": timedelta(minutes=5),
    "retry_exponential_backoff": True,
    "max_retry_delay": timedelta(minutes=30),
    "execution_timeout": timedelta(hours=2),
    "on_failure_callback": send_failure_notification,
    "sla_miss_callback": send_failure_notification,
}

# DBT configuration
DBT_PROJECT_DIR = "/usr/app/dbt"
DBT_PROFILES_DIR = "/usr/app/dbt"
DBT_TARGET = Variable.get("dbt_target", default_var="dev")
DBT_CONTAINER = "dataops-dbt"
