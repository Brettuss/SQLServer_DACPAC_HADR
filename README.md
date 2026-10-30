# SQL Server DACPAC and HADR lab

Run two SQL Server instances with Docker Compose to experiment with DACPAC deployment, database mirroring, Always On availability groups, and log shipping. Separate folders provide SQL Server 2019 and 2022 environments.

## Run the lab

From the repository root:

```bash
cd SQLServer_2022
docker compose up
```

Use `SQLServer_2019` instead for SQL Server 2019. Compose builds the images, starts both instances, and runs the setup scripts automatically. Allow time for SQL Server to start and initialization to finish; the default startup delay is 45 seconds.

The 2022 configuration enables mirroring, availability groups, and log shipping. The 2019 configuration disables all three by default. DACPAC installation is disabled in both.

Run one version at a time because both use the same container names and host ports.

## Connect

Use your preferred SQL Server client with SQL authentication:

| Instance | Server | Login |
| --- | --- | --- |
| `sqlserver1` | `localhost,1433` | `sa` |
| `sqlserver2` | `localhost,1434` | `sa` |

The password is the `SA_PASSWORD` value in the selected `docker-compose.yml`. For a local client that requires certificate validation, enable Trust Server Certificate.

`sqlserver1` starts as the mirroring principal, availability-group primary, and log-shipping primary. `sqlserver2` is the corresponding secondary.

## Optional configuration

Edit `x-environment` near the top of the selected `docker-compose.yml` to customize the lab. Both instances share these settings. Feature switches use the exact strings `"True"` and `"False"`.

| Variable | Purpose |
| --- | --- |
| `SA_PASSWORD` | Password for the `sa` login |
| `INIT_WAIT` | Seconds to wait before setup begins; default `45` |
| `ESTABLISH_MIRRORS` | Enable database mirroring |
| `MIRROR_DATABASE_NAME` | Mirroring database name; default `TestMirror` |
| `NUM_OF_MIRROR_DATABASES` | Number of mirrored databases; default `1` |
| `ESTABLISH_AG` | Enable availability group `AG1` |
| `AG_DATABASE_NAME` | Availability-group database name; default `TestAG` |
| `NUM_OF_AG_DATABASES` | Number of databases in `AG1`; default `1` |
| `ESTABLISH_LOG_SHIPPING` | Enable log shipping |
| `LOG_SHIPPING_DATABASE_NAME` | Log-shipping database name; default `LogShippingTest` |
| `NUM_OF_LOG_SHIPPING_DATABASES` | Number of log-shipped databases; default `1` |
| `INSTALL_DACPAC` | Enable DACPAC deployment; default `"False"` |
| `DACPAC_DATABASE_NAME` | Target database for the DACPAC |
| `DACPAC_FILENAME` | Filename of the DACPAC to deploy |
| `MSSQL_COLLATION` | Optional instance collation; commented out by default |

Enable any combination of the three replication options using distinct database names. With a database count of `1`, the name is used unchanged. Larger counts append numbers: a base name of `MirrorDB` and a count of `3` creates `MirrorDB1`, `MirrorDB2`, and `MirrorDB3`.

The availability group uses synchronous commit, automatic seeding, and manual failover. Log-shipping backup, copy, and restore jobs are scheduled every 15 minutes.

### Deploy a DACPAC

Place your `.dacpac` file in the selected version's `sql/dacpac/` folder, creating the folder if needed. Set `INSTALL_DACPAC` to `"True"`, set `DACPAC_FILENAME` to its filename, and set `DACPAC_DATABASE_NAME` to the target database.

Startup attempts to publish the package independently on both instances and skips databases that already exist. Use a different target name from the replication databases. Rebuild the images after changing the DACPAC or files under `sql/`.

## Stop and reset

Press Ctrl+C to stop the foreground lab. Use `docker compose down` to remove the containers, or `docker compose down --volumes` to also remove the shared certificates, backups, and setup marker files.

Database files are stored inside the containers, so removing or recreating a container deletes that instance's databases. Initialization runs on every start and can encounter existing objects when restarting an initialized lab. This repository is intended for disposable testing.
