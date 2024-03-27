#Wait to do anyhthing until backups are run on primary.
while [ ! -f /sql_files/backups_done.txt ]
do
  echo "Waiting for backups to run."
  sleep 2
done 

if [[ ! "$NUM_OF_MIRROR_DATABASES" ]] || [[ $NUM_OF_MIRROR_DATABASES -eq 1 ]]
then
  /opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "RESTORE DATABASE [$MIRROR_DATABASE_NAME] FROM DISK = N'/sql_files/$MIRROR_DATABASE_NAME.bak' WITH NORECOVERY"
  /opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "RESTORE LOG [$MIRROR_DATABASE_NAME] FROM DISK = N'/sql_files/$MIRROR_DATABASE_NAME.trn' WITH NORECOVERY"
  #Set Partner To Establish Mirror
  /opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "ALTER DATABASE [$MIRROR_DATABASE_NAME] SET PARTNER = 'TCP://sqlserver1:5022'"
else
  i=1
  while [ $i -le $NUM_OF_MIRROR_DATABASES ]
  do
    /opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "RESTORE DATABASE [$MIRROR_DATABASE_NAME$i] FROM DISK = N'/sql_files/$MIRROR_DATABASE_NAME$i.bak' WITH NORECOVERY"
    /opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "RESTORE LOG [$MIRROR_DATABASE_NAME$i] FROM DISK = N'/sql_files/$MIRROR_DATABASE_NAME$i.trn' WITH NORECOVERY"
    #Set Partner To Establish Mirror
    /opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "ALTER DATABASE [$MIRROR_DATABASE_NAME$i] SET PARTNER = 'TCP://sqlserver1:5022'"
    i=$((i+1))
  done
fi
echo "partners are set" > /sql_files/partners_set.txt
    