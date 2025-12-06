#!/bin/bash
for i in {1..3};
do
    sleep 10
    /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P $SA_PASSWORD -Q "SELECT 1" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "SQL Server is ready."
        break
    fi
    echo "Waiting for SQL Server..."
done

# Run the restore
echo "Restoring AdventureWorks..."
/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P $SA_PASSWORD -Q "RESTORE DATABASE AdventureWorks2014 FROM DISK = '/tmp/AdventureWorks2014.bak' WITH MOVE 'AdventureWorks2014_Data' TO '/var/opt/mssql/data/AdventureWorks2014_Data.mdf', MOVE 'AdventureWorks2014_Log' TO '/var/opt/mssql/data/AdventureWorks2014_Log.ldf', REPLACE"
echo "Done!"