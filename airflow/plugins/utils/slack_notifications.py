import json

import requests
from airflow.models import Variable
from airflow.utils import timezone


def send_slack_message(payload):
    try:
        webhook_url = Variable.get("slack_webhook_url")
        response = requests.post(
            webhook_url,
            data=json.dumps(payload),
            headers={"Content-Type": "application/json"},
        )
        if response.status_code != 200:
            print(f"❌ Failed to send Slack notification: {response.text}")
    except Exception as e:
        print(f"❌ Error sending Slack notification: {str(e)}")


def send_success_notification(**context):
    """
    Sends a GREEN notification with Run ID and calculated Duration.
    """
    dag_run = context["dag_run"]
    execution_date = context["execution_date"].strftime("%Y-%m-%d %H:%M")

    start_date = dag_run.start_date
    end_date = timezone.utcnow()

    duration_seconds = (end_date - start_date).total_seconds()
    formatted_duration = f"{duration_seconds:.2f}s"
    # --- FIX END ---

    payload = {
        "attachments": [
            {
                "color": "#36a64f",
                "blocks": [
                    {
                        "type": "header",
                        "text": {
                            "type": "plain_text",
                            "text": "✅ DBT Pipeline Success",
                            "emoji": True,
                        },
                    },
                    {
                        "type": "section",
                        "fields": [
                            {"type": "mrkdwn", "text": f"*DAG:*\n{dag_run.dag_id}"},
                            {"type": "mrkdwn", "text": f"*Run ID:*\n{dag_run.run_id}"},
                            {"type": "mrkdwn", "text": f"*Date:*\n{execution_date}"},
                            {
                                "type": "mrkdwn",
                                "text": f"*Duration:*\n{formatted_duration}",
                            },
                        ],
                    },
                ],
            }
        ]
    }
    send_slack_message(payload)


def send_failure_notification(context):
    """
    Sends a RED notification with Error details and Logs.
    """
    dag_run = context["dag_run"]
    task_instance = context["task_instance"]
    execution_date = context["execution_date"].strftime("%Y-%m-%d %H:%M")
    exception = context.get("exception", "Unknown error")
    log_url = task_instance.log_url.replace("localhost", "localhost")

    payload = {
        "attachments": [
            {
                "color": "#de4a4b",  # Red
                "blocks": [
                    {
                        "type": "header",
                        "text": {
                            "type": "plain_text",
                            "text": "❌ DBT Pipeline Failed",
                            "emoji": True,
                        },
                    },
                    {
                        "type": "section",
                        "fields": [
                            {
                                "type": "mrkdwn",
                                "text": f"*Task:*\n{task_instance.task_id}",
                            },
                            {"type": "mrkdwn", "text": f"*Date:*\n{execution_date}"},
                            {"type": "mrkdwn", "text": f"*Run ID:*\n{dag_run.run_id}"},
                        ],
                    },
                    {
                        "type": "section",
                        "text": {
                            "type": "mrkdwn",
                            "text": f"*Error:*\n```{str(exception)}```",
                        },
                    },
                    {
                        "type": "actions",
                        "elements": [
                            {
                                "type": "button",
                                "text": {"type": "plain_text", "text": "View Logs"},
                                "url": log_url,
                                "style": "danger",
                            }
                        ],
                    },
                ],
            }
        ]
    }
    send_slack_message(payload)
