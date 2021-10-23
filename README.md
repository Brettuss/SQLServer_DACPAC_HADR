# Introduction

SQL Server can be run on Linux using Docker containers.  This `README.md` file is a quick synopsis of how to get SQL Server up and running with Docker.

# Instructions - Plain SQL Server

First, view the [Docker Hub](https://hub.docker.com/_/microsoft-mssql-server) for SQL Server.

Second, view the [available environment variables](https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-configure-environment-variables?view=sql-server-ver15) when deploying SQL Server via containers.

## Download The Images

Pull the latest images for the version you would like to run.  As of this time (Sept 2021), images are available for SQL Server 2017 and 2019.

### SQL Server 2019

`docker pull mcr.microsoft.com/mssql/server:2019-latest`

### SQL Server 2017

`docker pull mcr.microsoft.com/mssql/server:2017-latest`

### Specific Version

To download a specific build, see the [Full Tag Listing](https://hub.docker.com/_/microsoft-mssql-server) section of the Docker Hub for SQL Server.

## Start The Container

### SQL Server 2019

The following command starts a container running the latest version of SQL Server 2019 with the SQL Server Agent enabled.

```bash
docker run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=password" -e "MSSQL_AGENT_ENABLED=True" -p 1433:1433 --name sqlserver -d mcr.microsoft.com/mssql/server:2019-latest
```
### SQL Server 2017

The following command starts a container running the latest version of SQL Server 2017 with the SQL Server Agent enabled.

```bash
docker run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=password" -e "MSSQL_AGENT_ENABLED=True" -p 1433:1433 --name sqlserver -d mcr.microsoft.com/mssql/server:2017-latest
```

# Instructions - With SQLCARE and HADR Configurations

The `docker-compose.yml` file also contains environment variables to configure SQLCARE and/or several HADR configurations.  These can be used in any combination with each other to deploy a variety of environment configurations.

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

## Creating the Environment

```bash
docker compose up -d
```

## Destroying the Environment

```bash
docker compose down --rmi all -v
```

You will need to issue the `--rmi all` and `-v` options to destroy the images and volumes created.

## Viewing Output Logs

You can view the output of the containers or individual containers by issuing the following commands:

### Environment Logs

```bash
docker compose logs -f
```

The `-f` option will follow the log output. If removed, only the log written up to that point in time will be output.

### Individual Container Logs

```bash
docker logs -f sqlserver1
```

```bash
docker logs -f sqlserver2
```