FROM python:3.9-slim-bullseye

# Set working directory
WORKDIR /usr/app/dbt

# Cài đặt system dependencies cho SQL Server
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    apt-transport-https \
    unixodbc \
    unixodbc-dev \
    && rm -rf /var/lib/apt/lists/*

# Cài đặt Microsoft ODBC Driver 17 for SQL Server
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
    && curl https://packages.microsoft.com/config/debian/10/prod.list > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y msodbcsql17 \
    && rm -rf /var/lib/apt/lists/*

# Cài đặt DBT và các packages cần thiết
RUN pip install --no-cache-dir \
    dbt-core==1.8.7 \
    dbt-sqlserver==1.8.7

# Copy DBT project files
COPY . .

# Set environment variables
ENV DBT_PROFILES_DIR=/usr/app/dbt

# Default command
CMD ["dbt", "--version"]
