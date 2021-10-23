# Introduction

This Docker Compose solution will create two SQL Server instances and establish HADR between them.  You can choose from Mirroring, Log Shipping or Always-On Availability Groups, or any combination of the three.  Additionally, you can install a DACPAC file of your choosing.

*Note: At this time, the `db-init.sh` script is not configured to identify if mirroring, availability groups, or log shipping has been previously established.  This means if you stop the environment (via command or a reboot, etc), the containers will attempt to configure HADR upon startup even if it is already configured. A change is in the works to address this limitation.*

## Environment Variables

The following environment variables are available for use.  You will find them in the `x-environment:` collection near the top of the file.


|Variable Name  |Type  |Default Value  |Description  |
|---------|---------|---------|---------|
|`INIT_WAIT`     | Integer         | 45         | Number of seconds the containers will wait before deploying the db-init.sh file.  Increase this number if the configuration scripts start running before the instance is ready.         |
|`INSTALL_SQLCARE`     | Boolean         | False         | If `True`, the SQLCARE DACPAC will be installed.         |
|`ESTABLISH_MIRRORS`     | Boolean         | False         | `True`: A mirror session will be established between `sqlserver1` and `sqlserver2` for database `MIRROR_DATABASE_NAME`. <br><br> `False`: A mirror session will not be established.        |
|`ESTABLISH_AG`     | Boolean         | False         | `True`: An availability group `AG1` will be created for database `AG_DATABASE_NAME`. <br><br> `False`: An availability group will not be created.         |
|`ESTABLISH_LOG_SHIPPING`     | Boolean        | False         | `True`: Log shipping will be established for database `LOG_SHIPPING_DATABASE_NAME` <br><br> `False`: Log shipping will not be established.        |
|`MIRROR_DATABASE_NAME`     | String         | MirrorTest         | The name of the database used when creating the database mirroring session.         |
|`AG_DATABASE_NAME`     | String         | AGTest         | The name of the database used when creating the `AG1` availability group.         |
|`LOG_SHIPPING_DATABASE_NAME`     | String         | LogShippingTest         | The name of the database used when establishing log shipping. |
