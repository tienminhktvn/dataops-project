from datetime import datetime

from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from airflow.utils.task_group import TaskGroup

# Import Modules
from config.settings import DBT_CONTAINER, DBT_PROFILES_DIR, DBT_TARGET, DEFAULT_ARGS
from utils.health_checks import check_pipeline_health
from utils.slack_notifications import (
    send_success_notification,
)

from airflow import DAG

with DAG(
    dag_id="dbt_dataops_pipeline",
    default_args=DEFAULT_ARGS,
    description="Complete DataOps pipeline orchestrating DBT transformations.",
    schedule_interval="0 1 * * *",
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["dbt", "dataops", "production", "daily"],
    max_active_runs=1,
    default_view="graph",
) as dag:
    # 1. Source Freshness
    check_source_freshness = BashOperator(
        task_id="check_source_freshness",
        bash_command=f"""
        echo "🔍 Checking source data freshness..." && \
        docker exec {DBT_CONTAINER} dbt source freshness \
            --profiles-dir {DBT_PROFILES_DIR} \
            --target {DBT_TARGET} && \
        echo "✅ Source freshness check complete"
        """,
        retries=0,
    )

    # 2. Model Execution Group
    with TaskGroup(
        group_id="dbt_model_execution", tooltip="Execute DBT models"
    ) as dbt_models:
        run_bronze = BashOperator(
            task_id="run_bronze_layer",
            bash_command=f"""
            echo "🥉 Bronze..." && \
            docker exec {DBT_CONTAINER} dbt run --profiles-dir {DBT_PROFILES_DIR} --target {DBT_TARGET} --select tag:bronze && \
            echo "✅ Done"
            """,
        )

        run_silver = BashOperator(
            task_id="run_silver_layer",
            bash_command=f"""
            echo "🥈 Silver..." && \
            docker exec {DBT_CONTAINER} dbt run --profiles-dir {DBT_PROFILES_DIR} --target {DBT_TARGET} --select tag:silver && \
            echo "✅ Done"
            """,
        )

        run_gold = BashOperator(
            task_id="run_gold_layer",
            bash_command=f"""
            echo "🥇 Gold..." && \
            docker exec {DBT_CONTAINER} dbt run --profiles-dir {DBT_PROFILES_DIR} --target {DBT_TARGET} --select tag:gold && \
            echo "✅ Done"
            """,
        )

        run_bronze >> run_silver >> run_gold

    # 3. Tests
    run_dbt_tests = BashOperator(
        task_id="run_data_quality_tests",
        bash_command=f"""
        echo "🧪 Testing..." && \
        docker exec {DBT_CONTAINER} dbt test --profiles-dir {DBT_PROFILES_DIR} --target {DBT_TARGET} && \
        echo "✅ Passed"
        """,
        trigger_rule="all_success",
    )

    # 4. Docs
    generate_documentation = BashOperator(
        task_id="generate_dbt_documentation",
        bash_command=f"""
        echo "📚 Generating..." && \
        docker exec {DBT_CONTAINER} dbt docs generate --profiles-dir {DBT_PROFILES_DIR} --target {DBT_TARGET}
        """,
        trigger_rule="all_done",
    )

    # 5. Health Check
    health_check = PythonOperator(
        task_id="pipeline_health_check",
        python_callable=check_pipeline_health,
        provide_context=True,
    )

    # 6. Success Notification
    notify_success = PythonOperator(
        task_id="send_success_notification",
        python_callable=send_success_notification,
        provide_context=True,
        trigger_rule="all_success",
    )

    # Flow
    check_source_freshness >> dbt_models >> run_dbt_tests
    run_dbt_tests >> health_check >> notify_success
    run_dbt_tests >> generate_documentation
