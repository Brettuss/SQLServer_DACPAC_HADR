#Run the db-init.sh file and then set SQL to start.
/bin/bash /tmp/db-init.sh &
/opt/mssql/bin/sqlservr
