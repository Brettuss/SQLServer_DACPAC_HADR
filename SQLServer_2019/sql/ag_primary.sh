/opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -q "CREATE AVAILABILITY GROUP [AG1]
    WITH (
        CLUSTER_TYPE = NONE
    )
    FOR REPLICA ON
    N'sqlserver1' WITH
    (
        ENDPOINT_URL = N'tcp://sqlserver1:5022',
        AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
        SEEDING_MODE = AUTOMATIC,
        FAILOVER_MODE = MANUAL,
        SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
    ),
    N'sqlserver2' WITH
    (
        ENDPOINT_URL = N'tcp://sqlserver2:5023',
        AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
        SEEDING_MODE = AUTOMATIC,
        FAILOVER_MODE = MANUAL,
        SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
    );"

if [[ ! "$NUM_OF_AG_DATABASES" ]] || [[ $NUM_OF_AG_DATABASES -eq 1 ]]
then
    /opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -q "CREATE DATABASE [$AG_DATABASE_NAME]"
    /opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -q "ALTER DATABASE [$AG_DATABASE_NAME] SET RECOVERY FULL"
    /opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d $AG_DATABASE_NAME -q "BACKUP DATABASE [$AG_DATABASE_NAME] TO DISK = '/sql_files/$AG_DATABASE_NAME.bak'"
    /opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d $AG_DATABASE_NAME -q "BACKUP LOG [$AG_DATABASE_NAME] TO DISK = '/sql_files/$AG_DATABASE_NAME.trn'"
    /opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "ALTER AVAILABILITY GROUP [AG1] ADD DATABASE [$AG_DATABASE_NAME]"
else
    i=1
    while [ $i -le $NUM_OF_AG_DATABASES ]
    do
        /opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -q "CREATE DATABASE [$AG_DATABASE_NAME$i]"
        /opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -q "ALTER DATABASE [$AG_DATABASE_NAME$i] SET RECOVERY FULL"
        /opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d $AG_DATABASE_NAME$i -q "BACKUP DATABASE [$AG_DATABASE_NAME$i] TO DISK = '/sql_files/$AG_DATABASE_NAME$i.bak'"
        /opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d $AG_DATABASE_NAME$i -q "BACKUP LOG [$AG_DATABASE_NAME$i] TO DISK = '/sql_files/$AG_DATABASE_NAME$i.trn'"
        /opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "ALTER AVAILABILITY GROUP [AG1] ADD DATABASE [$AG_DATABASE_NAME$i]"
        i=$((i+1))
    done
fi

echo "AGSet" > /sql_files/ag_set.txt