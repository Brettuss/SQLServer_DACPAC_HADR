#File used to create common logins and certs used
#across mirroring and AG
/opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "CREATE LOGIN sqlserver2 WITH PASSWORD = '$SA_PASSWORD'"
/opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "CREATE USER sqlserver2 FOR LOGIN sqlserver2"
/opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "CREATE MASTER KEY ENCRYPTION BY PASSWORD = '$SA_PASSWORD'"
/opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "CREATE CERTIFICATE sqlserver1_cert WITH SUBJECT = 'sqlserver1 certificate'"
/opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "CREATE ENDPOINT Endpoint_Mirroring STATE = STARTED AS TCP ( LISTENER_PORT=5022 , LISTENER_IP = ALL ) FOR DATABASE_MIRRORING ( AUTHENTICATION = CERTIFICATE sqlserver1_cert , ENCRYPTION = REQUIRED ALGORITHM AES , ROLE = ALL )"
/opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "BACKUP CERTIFICATE sqlserver1_cert TO FILE = '/sql_files/sqlserver1_cert.cer'"
#Import sqlserver2_cert and grant connection to Endpoint
while [ ! -f /sql_files/sqlserver2_cert.cer ]
do
  echo "SQLServer1: Waiting for sqlserver2_cert.cer file"
  sleep 2
done
/opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "CREATE CERTIFICATE sqlserver2_cert AUTHORIZATION [sqlserver2] FROM FILE = '/sql_files/sqlserver2_cert.cer'"
/opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "GRANT CONNECT ON ENDPOINT::Endpoint_Mirroring TO [sqlserver2]"