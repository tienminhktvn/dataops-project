FROM mcr.microsoft.com/mssql/server:2019-latest

USER root
RUN apt-get update && apt-get install -y curl gnupg2

# Install tools
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y mssql-tools unixodbc-dev

# Download Backup
RUN curl -L -o /tmp/AdventureWorks2014.bak https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2014.bak

# Copy Scripts
COPY restore_db.sh /tmp/restore_db.sh
COPY entrypoint.sh /tmp/entrypoint.sh
RUN chmod +x /tmp/restore_db.sh /tmp/entrypoint.sh

USER mssql

CMD ["/bin/bash", "/tmp/entrypoint.sh"]