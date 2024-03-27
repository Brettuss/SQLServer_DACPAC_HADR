if [[ ! "$NUM_OF_MIRROR_DATABASES" ]] || [[ $NUM_OF_MIRROR_DATABASES -eq 1 ]]
then
  /opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -q "CREATE DATABASE [$MIRROR_DATABASE_NAME]"
  /opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d $MIRROR_DATABASE_NAME -q "BACKUP DATABASE [$MIRROR_DATABASE_NAME] TO DISK = '/sql_files/$MIRROR_DATABASE_NAME.bak'"
  /opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d $MIRROR_DATABASE_NAME -q "BACKUP LOG [$MIRROR_DATABASE_NAME] TO DISK = '/sql_files/$MIRROR_DATABASE_NAME.trn'"
else
  i=1
  while [ $i -le $NUM_OF_MIRROR_DATABASES ]
  do
    /opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -q "CREATE DATABASE [$MIRROR_DATABASE_NAME$i]"
    /opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d $MIRROR_DATABASE_NAME$i -q "BACKUP DATABASE [$MIRROR_DATABASE_NAME$i] TO DISK = '/sql_files/$MIRROR_DATABASE_NAME$i.bak'"
    /opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d $MIRROR_DATABASE_NAME$i -q "BACKUP LOG [$MIRROR_DATABASE_NAME$i] TO DISK = '/sql_files/$MIRROR_DATABASE_NAME$i.trn'"
    i=$((i+1))
  done
fi

#set file to show backups are done.
echo "backups are done" > /sql_files/backups_done.txt

#Wait for mirror to set partner
while [ ! -f /sql_files/partners_set.txt ]
  do
    echo "Waiting for partners_set.txt"
    sleep 2
  done

#Set partner to establish mirror
if [[ ! "$NUM_OF_MIRROR_DATABASES" ]] || [[ $NUM_OF_MIRROR_DATABASES -eq 1 ]]
then
  /opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "ALTER DATABASE [$MIRROR_DATABASE_NAME] SET PARTNER = 'TCP://sqlserver2:5023'"
else
  i=1
  while [ $i -le $NUM_OF_MIRROR_DATABASES ]
  do
    /opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "ALTER DATABASE [$MIRROR_DATABASE_NAME$i] SET PARTNER = 'TCP://sqlserver2:5023'"
    i=$((i+1))
  done
fi
