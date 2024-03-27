#File used to create common logins and certs used
#across mirroring and AG
/opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "CREATE LOGIN sqlserver1 WITH PASSWORD = '$SA_PASSWORD'"
/opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "CREATE USER sqlserver1 FOR LOGIN sqlserver1"
/opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "CREATE MASTER KEY ENCRYPTION BY PASSWORD = '$SA_PASSWORD'"
/opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "CREATE CERTIFICATE sqlserver2_cert WITH SUBJECT = 'sqlserver2 certificate'"
/opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "CREATE ENDPOINT Endpoint_Mirroring STATE = STARTED AS TCP ( LISTENER_PORT=5023 , LISTENER_IP = ALL ) FOR DATABASE_MIRRORING ( AUTHENTICATION = CERTIFICATE sqlserver2_cert , ENCRYPTION = REQUIRED ALGORITHM AES , ROLE = ALL )"
/opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "BACKUP CERTIFICATE sqlserver2_cert TO FILE = '/sql_files/sqlserver2_cert.cer'"
#Import cert and grant permissions to endpoint for sqlserver1
while [ ! -f /sql_files/sqlserver1_cert.cer ]
do
  echo "SQLServer1: Waiting for sqlserver1_cert.cer file"
  sleep 2
done
/opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "CREATE CERTIFICATE sqlserver1_cert AUTHORIZATION sqlserver1 FROM FILE = '/sql_files/sqlserver1_cert.cer'"
/opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "GRANT CONNECT ON ENDPOINT::Endpoint_Mirroring TO [sqlserver1]"