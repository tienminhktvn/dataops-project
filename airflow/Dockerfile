FROM apache/airflow:2.7.0-python3.9

# Switch to root để cài đặt system packages
USER root

# Cài đặt Docker CLI để Airflow có thể gọi DBT container
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    lsb-release && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

RUN groupadd -g 999 docker || true && \
    usermod -aG docker airflow

# Switch về airflow user
USER airflow

ARG AIRFLOW_VERSION=2.7.0
ARG PYTHON_VERSION=3.9
ENV CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"

# Install packages
RUN pip install --no-cache-dir \
    apache-airflow-providers-docker \
    apache-airflow-providers-microsoft-mssql \
    --constraint "${CONSTRAINT_URL}"

# Set working directory
WORKDIR /opt/airflow