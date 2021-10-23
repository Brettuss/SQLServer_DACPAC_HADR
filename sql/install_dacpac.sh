echo "####### Installing SQLCARE DACPAC #######"

#run the setup script to create the DB and the schema in the DB
#if this is the primary node, remove the certificate files.
#if docker containers are stopped, but volumes are not removed, this certificate will be persisted
# Check if Database already exists

for i in {1..20};
do
    # Check if Database already exists
    RESULT=`/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P $SA_PASSWORD -Q "IF DB_ID('SQLCARE') IS NOT NULL PRINT 'YES'"`
    CODE=$?
    
    if [[ $RESULT == "YES" ]]
    then
        echo "SQLCARE database already exists. DACPAC will not be installed."
        break

    elif [[ $CODE -eq 0 ]] && [[ $RESULT == "" ]]
    then
        # Check if Database already exists
        RESULT=`/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P $SA_PASSWORD -Q "PRINT CAST(SERVERPROPERTY('COLLATION') AS VARCHAR)"`
        CODE=$?

        echo "SQLCARE database does not exist.  DACPAC will be installed."
        /opt/sqlpackage/sqlpackage /a:Publish /tsn:. /tdn:SQLCARE /tu:sa /tp:$SA_PASSWORD /sf:/tmp/dacpac/$RESULT/SQLCARE.dacpac
        #Update Backup and enable backup jobs
        /opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d SQLCARE -Q "UPDATE [dbo].[SQLBackupOptions] SET [BackupPath] = 'C:\sql_files'
        EXEC msdb.dbo.sp_update_job @job_name = 'SQLCARE - Backups - ALL_DATABASES - FULL', @enabled = 1
        EXEC msdb.dbo.sp_update_job @job_name = 'SQLCARE - Backups - ALL_DATABASES - DIFF', @enabled = 1
        EXEC msdb.dbo.sp_update_job @job_name = 'SQLCARE - Backups - ALL_DATABASES - LOG PRIMARY', @enabled = 1"
        break
        
    # If the code is different than 0, an error occured. (most likely database wasn't online) Retry.
    else
        echo "Database not ready yet..."
        sleep 1
    fi
done

echo "####### SQLCARE DACPAC Installed #######"