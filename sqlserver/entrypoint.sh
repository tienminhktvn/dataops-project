#!/bin/bash
/opt/mssql/bin/sqlservr & 
pid=$!

# Run the restore script
/tmp/restore_db.sh

# Wait on the SQL Server process
wait $pid