echo "####### Installing DACPAC #######"

#run the setup script to create the DB and the schema in the DB
#if this is the primary node, remove the certificate files.
#if docker containers are stopped, but volumes are not removed, this certificate will be persisted
# Check if Database already exists

for i in {1..20};
do
    # Check if Database already exists
    RESULT=`/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P $SA_PASSWORD -Q "IF DB_ID('$DACPAC_DATABASE_NAME') IS NOT NULL PRINT 'YES'"`
    CODE=$?
    
    if [[ $RESULT == "YES" ]]
    then
        echo "$DACPAC_DATABASE_NAME database already exists. DACPAC will not be installed."
        break

    elif [[ $CODE -eq 0 ]] && [[ $RESULT == "" ]]
    then
        
        echo "$DACPAC_DATABASE_NAME database does not exist.  DACPAC will be installed."
        /opt/sqlpackage/sqlpackage /a:Publish /tsn:. /tdn:$DACPAC_DATABASE_NAME /tu:sa /tp:$SA_PASSWORD /sf:/tmp/dacpac/$DACPAC_FILENAME
        break
        
    # If the code is different than 0, an error occured. (most likely database wasn't online) Retry.
    else
        echo "Database not ready yet..."
        sleep 1
    fi
done

echo "####### DACPAC Installed #######"
