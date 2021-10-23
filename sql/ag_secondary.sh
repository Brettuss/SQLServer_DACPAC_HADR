while [ ! -f /sql_files/ag_set.txt ]
do
  echo "Waiting for ag_set.txt"
  sleep 2
done

echo "AG set on primary, waiting 10 seconds to join secondary replicas."
sleep 10

 /opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "ALTER AVAILABILITY GROUP [AG1] JOIN WITH (CLUSTER_TYPE = NONE)"

 /opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "ALTER AVAILABILITY GROUP [AG1] GRANT CREATE ANY DATABASE"