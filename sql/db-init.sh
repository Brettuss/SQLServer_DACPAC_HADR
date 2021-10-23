#!/bin/bash

#wait for the SQL Server to come up
SLEEP_TIME=$INIT_WAIT

if [ ! "$INIT_WAIT" ]
then
    SLEEP_TIME=30
fi

#Check environment variables

if [ ! "$INSTALL_SQLCARE" ]
then
    INSTALL_SQLCARE="False"
fi

if [ ! "$ESTABLISH_MIRROR" ]
then
    ESTABLISH_MIRROR="False"
fi

if [ ! "$NUM_OF_MIRROR_DATABASES" ]
then
    export NUM_OF_MIRROR_DATABASES=1
fi

if [ ! "$ESTABLISH_AG" ]
then
    ESTABLISH_AG="False"
fi

if [ ! "$NUM_OF_AG_DATABASES" ]
then
    export NUM_OF_AG_DATABASES=1
fi

if [ ! "$ESTABLISH_LOG_SHIPPING" ]
then
    ESTABLISH_LOG_SHIPPING="False"
fi

if [ ! "$NUM_OF_LOG_SHIPPING_DATABASES" ]
then
    export NUM_OF_LOG_SHIPPING_DATABASES=1
fi

echo "sleeping for ${SLEEP_TIME} seconds ..."
sleep ${SLEEP_TIME}

#Clear out the volume in case it wasn't done with last docker compose down
rm /sql_files/*

#Execute Common Script
#This script creates logins and certs needed
#regardless of how env variables are set.
if [[ $COMMON_SCRIPT == "common_sqlserver1.sh" ]]
then
    export MIRROR_ROLE="principal"
    export AG_ROLE="primary"
    export LOG_SHIPPING_ROLE="primary"
    
elif [[ $COMMON_SCRIPT == "common_sqlserver2.sh" ]]
then
    export MIRROR_ROLE="mirror"
    export AG_ROLE="secondary"
    export LOG_SHIPPING_ROLE="secondary"
fi
/bin/bash /tmp/$COMMON_SCRIPT

#Set the database names if they haven't been set in docker-compose file.
if [[ ! "$MIRROR_DATABASE_NAME" ]]
then
    echo "MIRROR_DATABASE_NAME not set, setting default value."
    export MIRROR_DATABASE_NAME="TestMirror"
    echo "MIRROR_DATABASE_NAME = $MIRROR_DATABASE_NAME"
fi

if [[ ! "$AG_DATABASE_NAME" ]]
then
    echo "AG_DATABASE_NAME not set, setting default value."
    export AG_DATABASE_NAME="TestAG"
    echo "AG_DATABASE_NAME = $AG_DATABASE_NAME"
fi

if [[ ! "$LOG_SHIPPING_DATABASE_NAME" ]]
then
    echo "LOG_SHIPPING_DATABASE_NAME not set, setting default value."
    export LOG_SHIPPING_DATABASE_NAME="LogShippingTest"
    echo "LOG_SHIPPING_DATABASE_NAME = $LOG_SHIPPING_DATABASE_NAME"
fi

#Check to see if we need to install SQLCARE.

if [[ $INSTALL_SQLCARE == "True" ]]
then
    /bin/bash /tmp/install_sqlcare.sh
fi

#Check to see if we're establishing mirrors.
if [[ $ESTABLISH_MIRRORS == "True" ]]
then

    if [ ! "$MIRROR_ROLE" ]
    then
        echo "!!! - MIRROR_ROLE Environment Variable Not Defined - Mirroring will not be established."
    else
        echo "ESTABLISH_MIRRORS is True - Establishing mirrors."

        if [[ $MIRROR_ROLE = "principal" ]]
        then
            /bin/bash /tmp/mirroring_primary.sh
        elif [[ $MIRROR_ROLE = "mirror" ]]
        then
            /bin/bash /tmp/mirroring_secondary.sh
        else
            echo "MIRROR_ROLE environment variable value invalid."
            echo "Available values are: principal, mirror"
        fi

    fi

fi

#Check to see if we're establishing AG
if [[ $ESTABLISH_AG == "True" ]] && [[ $MSSQL_ENABLE_HADR -eq 1 ]]
then

    if [ ! "$AG_ROLE" ]
    then
        echo "!!! - AG_ROLE Environment Variable Not Defined - AG will not be established."
    else

        if [[ $AG_ROLE == "primary" ]]
        then
            /bin/bash /tmp/ag_primary.sh
        elif [[ $AG_ROLE == "secondary" ]]
        then
            /bin/bash /tmp/ag_secondary.sh
        else
            echo "AG_ROLE environment variable value invalid."
            echo "Available values are: primary, secondary"
        fi

    fi
elif [[ ! $MSSQL_ENABLE_HADR -eq 1 ]]
then
    echo "MSSQL_ENABLE_HADR not set to 1, AG will not be created and established."    
fi

#Check to see if we're establishing log shipping.
if [[ $ESTABLISH_LOG_SHIPPING == "True" ]]
then

    if [ ! "$LOG_SHIPPING_ROLE" ]
    then
        echo "!!! - LOG_SHIPPING_ROLE Environment Variable Not Defined - Log Shipping will not be established."
    else

        if [[ $LOG_SHIPPING_ROLE == "primary" ]]
        then
            /bin/bash /tmp/log_shipping_primary.sh
        elif [[ $LOG_SHIPPING_ROLE == "secondary" ]]
        then
            /bin/bash /tmp/log_shipping_secondary.sh
        else
            echo "LOG_SHIPPING_ROLE environment variable value invalid."
            echo "Available values are: primary, secondary"
        fi

    fi
fi
