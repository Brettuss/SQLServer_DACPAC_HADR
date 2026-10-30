# SQL Server DACPAC and HADR lab

This repository builds a disposable, two-instance SQL Server lab with Docker Compose. Choose SQL Server 2019 or 2022, optionally publish a DACPAC, and configure database mirroring, an Always On availability group, log shipping, or a combination using separate databases.

Use it to experiment with database deployment, replication, and SQL Server administration. Both instances run on the same Docker host and share a backup directory. The repository does not provision a production HA cluster, an availability-group listener, automatic failover, or durable database storage.

> **Current setup limitations:** The initialization scripts contain a shared-directory cleanup race, and the 2022 DACPAC installer still uses an older `sqlcmd` path. Read [Setup corrections and known limitations](#setup-corrections-and-known-limitations) before building. Container startup alone does not confirm that initialization succeeded.

## Contents

- [What gets created](#what-gets-created)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Configuration reference](#configuration-reference)
- [Workflow examples](#workflow-examples)
- [Connect and verify](#connect-and-verify)
- [Stop, rebuild, and reset](#stop-rebuild-and-reset)
- [Setup corrections and known limitations](#setup-corrections-and-known-limitations)
- [Troubleshooting](#troubleshooting)
- [Repository layout](#repository-layout)

## What gets created

Each version directory is a standalone Compose project containing:

| Component | Purpose |
| --- | --- |
| `sqlserver1` | Initial mirroring principal, AG primary, and log-shipping primary; host SQL port `1433` |
| `sqlserver2` | Initial mirroring mirror, AG secondary, and log-shipping secondary; host SQL port `1434` |
| `sqlserver` network | Container DNS and communication between the two instances |
| `sql_files` named volume | Shared `/sql_files` directory for certificates, backup files, and initialization marker files |
| Custom image | Microsoft SQL Server image plus SqlPackage, initialization scripts, and any supplied DACPAC |

Inside the Docker network, SQL connections use `sqlserver1,1433` and `sqlserver2,1433`. The second instance's host port `1434` maps to its container port `1433`. Mirroring/AG endpoints use `sqlserver1:5022` and `sqlserver2:5023`; those ports are internal and are not published to the host.

The two version directories have the same overall design, with these differences in the current files:

| Setting | SQL Server 2019 | SQL Server 2022 |
| --- | --- | --- |
| Base image | `mcr.microsoft.com/mssql/server:2019-latest` | `mcr.microsoft.com/mssql/server:2022-latest` |
| Mirroring, AG, log shipping enabled by default | All `"False"` | All `"True"` |
| HADR scripts' `sqlcmd` | `/opt/mssql-tools/bin/sqlcmd` | `/opt/mssql-tools18/bin/sqlcmd -C` |
| DACPAC enabled by default | `"False"` | `"False"` |

Both Dockerfiles enable SQL Server Agent and HADR and set SQL Server's memory limit to **2048 MB per instance**. This SQL setting is not a Docker container memory limit.

### Initialization sequence

`entrypoint.sh` starts `db-init.sh` in the background and runs SQL Server in the foreground. On **every container start**, initialization:

1. Waits `INIT_WAIT` seconds; this is a fixed delay, not a readiness probe.
2. Clears the shared directory in the checked-in implementation; see the correction below.
3. Assigns roles using `COMMON_SCRIPT`, creates endpoint logins/users and master keys, creates certificates, exchanges public certificates through `/sql_files`, and grants endpoint access. This happens even when all optional workflows are disabled, so both containers must run.
4. Optionally publishes the DACPAC on each instance.
5. Optionally creates mirroring databases and establishes partners.
6. Optionally creates `AG1`, adds its databases, and joins/seeds the secondary.
7. Optionally creates log-shipping databases and SQL Server Agent jobs.

Scripts coordinate by polling shared marker files. There is no overall completion signal, timeout for those waits, or Compose health check.

## Requirements

- Docker Engine or Docker Desktop configured for Linux containers, with Docker Compose v2 (`docker compose`).
- An x86-64 environment for the SQL Server Linux images. Microsoft supports these images on Intel/AMD Linux hosts; ARM emulation is not a supported SQL Server deployment. See [Microsoft's platform guidance](https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-setup).
- Enough memory for two SQL Server instances plus Docker and the operating system. Budget more than the combined 4 GB SQL memory settings, and enough disk for images, databases, and backups.
- Internet access during image builds for Microsoft's registry, Ubuntu packages, the Dockerfiles' legacy OpenSSL package, and the SqlPackage download.
- Host ports `1433` and `1434` available, or edited host port mappings.
- A SQL Server client such as SSMS or `sqlcmd`, or use the client inside each container as shown below.
- A prebuilt, compatible `.dacpac` if using DACPAC deployment. This repository contains no SQL database project or sample DACPAC.

The commands below use Bash and run from the selected version directory unless stated otherwise. Set `ACCEPT_EULA: "Y"` only if you accept the SQL Server license terms. The Compose files do not explicitly select an edition using `MSSQL_PID`.

## Quick start

1. From the repository root, choose one version:

   ```bash
   cd SQLServer_2022
   # Or: cd SQLServer_2019
   ```

   Run one version at a time: both projects explicitly use container names `sqlserver1` and `sqlserver2` and the same host ports.

2. Apply the [shared-directory correction](#shared-directory-cleanup) in the selected version's `sql/db-init.sh` before building.

3. Edit `docker-compose.yml`. Set a strong `SA_PASSWORD` in `x-environment`, then choose the workflows to enable. For an AG-only first run, use these entries in the existing `x-environment` block, retaining its other settings:

   ```yaml
   SA_PASSWORD: "ReplaceWithAStrongLabPassword123!"
   INIT_WAIT: 45
   INSTALL_DACPAC: "False"
   ESTABLISH_MIRRORS: "False"
   ESTABLISH_AG: "True"
   ESTABLISH_LOG_SHIPPING: "False"
   MSSQL_ENABLE_HADR: 1
   AG_DATABASE_NAME: "TestAG"
   NUM_OF_AG_DATABASES: 1
   ```

   Choose your own password rather than retaining the example. The scripts interpolate it into shell arguments and SQL literals without robust escaping; avoid spaces, single quotes, and shell metacharacters. Compose also interprets `$` in YAML values; a literal dollar requires `$$`.

4. Validate and start both services:

   ```bash
   docker compose config --quiet
   docker compose up -d --build
   docker compose ps
   docker compose logs -f sqlserver1 sqlserver2
   ```

   Allow time beyond `INIT_WAIT` for certificate exchange and AG seeding. Press Ctrl+C to leave log following; detached containers continue running. The legacy `version: "3.9"` field may produce an obsolete-field warning with Compose v2.

5. Use the [verification queries](#connect-and-verify) to confirm `AG1` and database synchronization on both instances. Review SQL errors in the logs even when both containers show as running.

## Configuration reference

Edit the shared `x-environment: &common-variables` block in the chosen `docker-compose.yml`. Both services inherit it through `<<: *common-variables`.

The workflow switches are **case-sensitive strings**: use `"True"` or `"False"`. Database counts must be positive integers. Use simple, distinct database names, such as letters, digits, and underscores: names are also used in shell arguments and file paths without comprehensive escaping.

| Variable | Current Compose value or script fallback | Meaning |
| --- | --- | --- |
| `SA_PASSWORD` | `!<YourPassword>!` | Shared `sa` password, also used for endpoint logins and master keys; replace before use |
| `ACCEPT_EULA` | `"Y"` | SQL Server license acceptance |
| `MSSQL_AGENT_ENABLED` | `"True"` | Enables SQL Server Agent, required by log-shipping jobs |
| `INIT_WAIT` | `45`; script fallback `30` if unset/empty | Seconds before initialization begins |
| `INSTALL_DACPAC` | `"False"` | Attempts DACPAC publication on both instances |
| `DACPAC_DATABASE_NAME` | `YourDatabase` | DACPAC target database; no separate fallback in the installer |
| `DACPAC_FILENAME` | `YourFile.dacpac` | Filename under the selected version's `sql/dacpac/` directory |
| `ESTABLISH_MIRRORS` | 2019: `"False"`; 2022: `"True"` | Creates database-mirroring sessions |
| `MIRROR_DATABASE_NAME` | `TestMirror` if unset/empty | Mirroring database name or prefix |
| `NUM_OF_MIRROR_DATABASES` | `1` if unset/empty | Number of mirroring databases |
| `ESTABLISH_AG` | 2019: `"False"`; 2022: `"True"` | Creates availability group `AG1` |
| `AG_DATABASE_NAME` | `TestAG` if unset/empty | AG database name or prefix |
| `NUM_OF_AG_DATABASES` | `1` if unset/empty | Number of databases added to `AG1` |
| `MSSQL_ENABLE_HADR` | `1` | Must be `1` for the AG setup branch to run |
| `ESTABLISH_LOG_SHIPPING` | 2019: `"False"`; 2022: `"True"` | Creates log-shipping configuration and jobs |
| `LOG_SHIPPING_DATABASE_NAME` | `LogShippingTest` if unset/empty | Log-shipping database name or prefix |
| `NUM_OF_LOG_SHIPPING_DATABASES` | `1` if unset/empty | Number of log-shipping databases |
| `MSSQL_COLLATION` | Commented out | Optional instance collation; uncomment/set before first database initialization |
| `COMMON_SCRIPT` | Service-specific | `common_sqlserver1.sh` on the first service and `common_sqlserver2.sh` on the second; determines initial roles |

The commented database names (`MirrorDB`, `AGDB`, `LogShippingDB`) are examples, not active defaults. Role variables (`MIRROR_ROLE`, `AG_ROLE`, `LOG_SHIPPING_ROLE`) are assigned by `db-init.sh`; changing them in Compose does not override that assignment.

The Compose values are literal YAML values. Exporting `ESTABLISH_AG=True` in your terminal or creating a `.env` file does not override them unless you also change the YAML to use interpolation. Configuration changes take effect when containers are recreated; follow the [fresh-lab reset procedure](#stop-rebuild-and-reset) when changing workflows.

### Database naming and counts

With a count of `1`, the database uses the base name unchanged. With a count greater than `1`, all databases receive a numeric suffix starting at `1`:

| Base name | Count | Result |
| --- | --- | --- |
| `MirrorDB` | `1` | `MirrorDB` |
| `MirrorDB` | `3` | `MirrorDB1`, `MirrorDB2`, `MirrorDB3` |
| `AGDB` | `2` | `AGDB1`, `AGDB2`, both in `AG1` |

Keep names distinct across workflows and the startup DACPAC target. HADR setup scripts issue `CREATE DATABASE`; they do not adopt an existing DACPAC database or update an existing HADR configuration.

## Workflow examples

### Choose a replication mode

Set these switches in the existing shared environment block:

| Scenario | `ESTABLISH_MIRRORS` | `ESTABLISH_AG` | `ESTABLISH_LOG_SHIPPING` |
| --- | --- | --- | --- |
| Two instances with common endpoint setup only | `"False"` | `"False"` | `"False"` |
| Mirroring only | `"True"` | `"False"` | `"False"` |
| Availability group only | `"False"` | `"True"` | `"False"` |
| Log shipping only | `"False"` | `"False"` | `"True"` |
| All three, with separate databases | `"True"` | `"True"` | `"True"` |

- **Mirroring:** Creates full and transaction-log backups on `sqlserver1`, restores them with `NORECOVERY` on `sqlserver2`, and sets partners using the certificate-authenticated endpoints. No witness or automatic failover is configured. The mirror database is not available for normal queries.
- **Availability group:** Creates `AG1` with `CLUSTER_TYPE = NONE`, synchronous commit, automatic seeding, manual failover, and connections allowed to the secondary. There is no listener or read-only routing configuration. Connect directly to each instance. A clusterless AG has no automatic failover; see [Microsoft's read-scale AG guidance](https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-availability-group-configure-rs).
- **Log shipping:** Creates initial full/log backups, restores the secondary with `NORECOVERY`, and registers backup, copy, restore, and alert jobs. Backup/copy/restore schedules run every **15 minutes**. The secondary stays in restoring mode and is not readable. Apply the shared-directory correction and review [log-shipping caveats](#log-shipping-caveats) first.

Mirroring and log shipping rely on databases being in FULL recovery for log backups. Their scripts do not explicitly set that recovery model; AG setup does. Check the recovery model if initialization reports log-backup errors, especially if you change `model` or customize database creation.

### Create multiple databases in each mode

For example, add/uncomment these values in `x-environment`:

```yaml
ESTABLISH_MIRRORS: "True"
MIRROR_DATABASE_NAME: "MirrorDB"
NUM_OF_MIRROR_DATABASES: 3
ESTABLISH_AG: "True"
MSSQL_ENABLE_HADR: 1
AG_DATABASE_NAME: "AGDB"
NUM_OF_AG_DATABASES: 2
ESTABLISH_LOG_SHIPPING: "True"
LOG_SHIPPING_DATABASE_NAME: "LogShippingDB"
NUM_OF_LOG_SHIPPING_DATABASES: 2
```

This requests three mirrored databases, two databases in one AG (`AG1`), and two log-shipped databases. It does not create multiple availability groups. Start from a fresh lab after changing counts or names. More databases require more time, storage, and memory.

### Publish a DACPAC at startup

1. Create the input directory in the selected version and copy your existing package into it:

   ```bash
   mkdir -p sql/dacpac
   cp /path/to/YourFile.dacpac sql/dacpac/YourFile.dacpac
   ```

2. Set the following in the shared environment block for a standalone deployment example:

   ```yaml
   INSTALL_DACPAC: "True"
   DACPAC_DATABASE_NAME: "AppDatabase"
   DACPAC_FILENAME: "YourFile.dacpac"
   ESTABLISH_MIRRORS: "False"
   ESTABLISH_AG: "False"
   ESTABLISH_LOG_SHIPPING: "False"
   ```

3. Check the [DACPAC compatibility corrections](#dacpac-and-client-compatibility), then build/start both services:

   ```bash
   docker compose up -d --build
   docker compose logs -f sqlserver1 sqlserver2
   ```

The build copies the entire `sql/` directory into `/tmp/`, including `sql/dacpac/YourFile.dacpac` as `/tmp/dacpac/YourFile.dacpac`. Rebuild the image after changing the package or scripts.

The startup installer publishes to **both instances independently** when the target database does not exist. It checks existence up to 20 times and skips publication if the database already exists. It does not perform ongoing schema upgrades. Two successful publications do not establish replication between the resulting databases.

You may combine this with HADR using different database names. Reusing `AppDatabase` as a HADR database name causes creation conflicts, and publishing it independently to the secondary prevents automatic AG seeding into that name.

### Publish manually, including to an AG primary

For an existing database or a repeat deployment, run SqlPackage explicitly. This example publishes to the AG-only quick start's `TestAG` on `sqlserver1`, after AG initialization succeeds:

```bash
docker compose exec sqlserver1 mkdir -p /tmp/dacpac
docker compose cp ./sql/dacpac/YourFile.dacpac sqlserver1:/tmp/dacpac/YourFile.dacpac
docker compose exec sqlserver1 bash -lc '
  /opt/sqlpackage/sqlpackage \
    /Action:Publish \
    /SourceFile:/tmp/dacpac/YourFile.dacpac \
    /TargetServerName:localhost \
    /TargetDatabaseName:TestAG \
    /TargetUser:sa \
    /TargetPassword:"$SA_PASSWORD" \
    /TargetTrustServerCertificate:True
'
```

Replace the target name as appropriate and review the package's deployment changes before applying it. For an AG database, publish to its current primary and verify the secondary afterward. Keep `INSTALL_DACPAC: "False"` for this workflow so startup does not separately create the target on both instances. The trust option accommodates the lab server certificate; see [SqlPackage Publish parameters](https://learn.microsoft.com/en-us/sql/tools/sqlpackage/sqlpackage-publish).

## Connect and verify

For a client on the Docker host, use SQL authentication with login `sa` and the configured password:

| Instance | Client server address | Example ADO.NET connection string |
| --- | --- | --- |
| Primary | `localhost,1433` | `Server=localhost,1433;Database=master;User ID=sa;Password=<password>;Encrypt=True;TrustServerCertificate=True;` |
| Secondary | `localhost,1434` | `Server=localhost,1434;Database=master;User ID=sa;Password=<password>;Encrypt=True;TrustServerCertificate=True;` |

Trusting the server certificate is for this local lab. The certificate-authenticated mirroring/AG endpoint is separate from the SQL client connection. From another container on the Compose network, use the service names and container port `1433`.

### Use the bundled SQL client

For the current 2022 image/scripts:

```bash
docker compose exec sqlserver1 bash -lc \
  '/opt/mssql-tools18/bin/sqlcmd -S localhost -C -U sa -P "$SA_PASSWORD" -b -Q "SELECT @@SERVERNAME AS server_name, @@VERSION AS version;"'

docker compose exec sqlserver2 bash -lc \
  '/opt/mssql-tools18/bin/sqlcmd -S localhost -C -U sa -P "$SA_PASSWORD" -b -Q "SELECT name, state_desc, recovery_model_desc FROM sys.databases;"'
```

The single quotes let the shell **inside the container** expand its password variable. For the 2019 scripts' expected client, replace `/opt/mssql-tools18/bin/sqlcmd` with `/opt/mssql-tools/bin/sqlcmd`; confirm the actual path in your built image because the base image tags are mutable. `-C` trusts the lab certificate, and `-b` makes the verification command return failure on SQL errors.

For an interactive session, use:

```bash
docker compose exec sqlserver1 bash -lc \
  '/opt/mssql-tools18/bin/sqlcmd -S localhost -C -U sa -P "$SA_PASSWORD"'
```

Enter a query followed by `GO` on a separate line; type `QUIT` to exit. Run the queries below against both instances using this session or your preferred SQL client.

### Check mirroring

```sql
SELECT DB_NAME(database_id) AS database_name,
       mirroring_role_desc,
       mirroring_state_desc,
       mirroring_safety_level_desc,
       mirroring_partner_name
FROM sys.database_mirroring
WHERE mirroring_guid IS NOT NULL;
GO
```

Expect `PRINCIPAL` on `sqlserver1`, `MIRROR` on `sqlserver2`, and `SYNCHRONIZED` after synchronization. A mirror database's restoring state is expected; query the principal for its data.

### Check the availability group

```sql
SELECT ag.name AS availability_group,
       ar.replica_server_name,
       ars.is_local,
       ars.role_desc,
       ars.connected_state_desc,
       ars.synchronization_health_desc
FROM sys.availability_groups AS ag
JOIN sys.availability_replicas AS ar ON ar.group_id = ag.group_id
LEFT JOIN sys.dm_hadr_availability_replica_states AS ars
       ON ars.replica_id = ar.replica_id;

SELECT adc.database_name,
       drs.is_local,
       drs.synchronization_state_desc,
       drs.synchronization_health_desc,
       drs.database_state_desc
FROM sys.dm_hadr_database_replica_states AS drs
JOIN sys.availability_databases_cluster AS adc
     ON adc.group_database_id = drs.group_database_id;
GO
```

Expect local roles `PRIMARY` and `SECONDARY`, connected replicas, and synchronized/healthy databases once automatic seeding finishes. A secondary has less visibility into remote replica state, so run these on both servers.

To test data movement with the AG-only quick start, run on `sqlserver1` once:

```sql
USE [TestAG];
CREATE TABLE dbo.ReplicationProbe (id int NOT NULL PRIMARY KEY, message nvarchar(100));
INSERT dbo.ReplicationProbe (id, message) VALUES (1, N'Created on sqlserver1');
GO
```

Then run on `sqlserver2` after synchronization:

```sql
SELECT id, message FROM TestAG.dbo.ReplicationProbe;
GO
```

Replace `TestAG` if you changed the name/count. Remove the test table from the primary when finished with `DROP TABLE TestAG.dbo.ReplicationProbe;`.

### Check log shipping and Agent jobs

Run on the primary:

```sql
SELECT primary_database, backup_directory, backup_share
FROM msdb.dbo.log_shipping_primary_databases;
GO
```

Run on the secondary:

```sql
SELECT s.primary_server, s.primary_database, d.secondary_database,
       d.restore_mode, d.restore_delay,
       s.last_copied_file, d.last_restored_file, d.last_restored_date
FROM msdb.dbo.log_shipping_secondary AS s
JOIN msdb.dbo.log_shipping_secondary_databases AS d
     ON d.secondary_id = s.secondary_id;
GO
```

Run on both to inspect jobs and their latest outcome messages:

```sql
SELECT name, enabled FROM msdb.dbo.sysjobs WHERE name LIKE N'LS%';

SELECT TOP (20) j.name, h.run_date, h.run_time, h.run_status, h.message
FROM msdb.dbo.sysjobhistory AS h
JOIN msdb.dbo.sysjobs AS j ON j.job_id = h.job_id
WHERE j.name LIKE N'LS%' AND h.step_id = 0
ORDER BY h.instance_id DESC;
GO
```

An empty history immediately after setup can mean the 15-minute jobs have not run yet. Check subsequent backup, copy, and restore job successes; job definitions and marker files alone do not prove that logs are moving. `run_status = 1` indicates success and `0` failure. The secondary databases should remain `RESTORING`. The secondary query joins the [server-level copy metadata](https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/log-shipping-secondary-transact-sql) with the [database-level restore metadata](https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/log-shipping-secondary-databases-transact-sql).

## Stop, rebuild, and reset

The Compose files mount only `/sql_files`. They do **not** mount `/var/opt/mssql`, so SQL database files and server configuration live in each container's writable layer.

| Action | Data and initialization behavior |
| --- | --- |
| `docker compose stop` | Stops existing containers and keeps their writable layers |
| `docker compose start` / `restart` | Reruns initialization against existing SQL state; can cause duplicate-object errors and shared-file deletion |
| `docker compose down` | Removes containers and their database files; retains the named shared volume |
| `docker compose down --volumes` | Removes containers, database files, and the project's shared volume |
| Recreate a container | Loses that container's database files under the current configuration |

Treat these labs as disposable. Export any data you need before removal or recreation. The shared backup volume is not a complete persistence strategy.

For a clean run after changing configuration, scripts, or packages, the following **deletes the existing lab and its shared files**:

```bash
docker compose down --volumes
docker compose up -d --build
```

The images remain cached. Changes under `sql/` require rebuilding because those files are copied into the image, not bind-mounted. To fetch a newer base image as well, use `docker compose build --pull` before starting the fresh lab; review compatibility changes because `*-latest` is not pinned.

To preserve databases across container recreation, you would need separate persistent mounts for each instance's `/var/opt/mssql` **and** initialization that detects existing configuration. Adding volumes alone does not fix the scripts' restart behavior.

## Setup corrections and known limitations

These limitations describe the checked-in implementation. The corrections below are manual edits in your chosen version; they are not automatically applied by Compose.

### Shared-directory cleanup

Both versions' `sql/db-init.sh` run:

```bash
rm -rf /sql_files/*
```

Because both containers share this path, one can delete certificates or marker files that the other has just written. It also deletes the Dockerfile-created `ls_backups` and `ls_copies` directories before log shipping uses them.

For fresh, disposable lab runs, replace that line in the selected version's `sql/db-init.sh` with:

```bash
mkdir -p /sql_files/ls_backups /sql_files/ls_copies
```

Rebuild afterward. Clear stale certificates, backups, and markers by running `docker compose down --volumes` between lab runs instead of deleting the shared files from both initializing containers. This correction addresses the cleanup race and missing directories; it does not make initialization safe to rerun against existing SQL state.

### DACPAC and client compatibility

- **2022 startup installer path:** `SQLServer_2022/sql/install_dacpac.sh` still calls `/opt/mssql-tools/bin/sqlcmd`, while the other 2022 scripts use `/opt/mssql-tools18/bin/sqlcmd -C`. Before enabling startup DACPAC installation on an image with tools18, change the installer's check to use `/opt/mssql-tools18/bin/sqlcmd -C` too, then rebuild.
- **2019 client assumptions:** All 2019 scripts assume the older `/opt/mssql-tools/bin/sqlcmd` path. Check it against the actual base image and update consistently if needed.
- **SqlPackage TLS:** The installer downloads SqlPackage from an unpinned URL and does not pass a certificate-trust option. If publishing fails on the lab's server certificate, add `/TargetTrustServerCertificate:True` to the publish command for this lab, or use the manual example above.
- **Success logging:** The installer prints `DACPAC Installed` even if its retries fail or SqlPackage returns an error. Verify the target database and expected schema directly.

### Log-shipping caveats

- The primary registers its secondary as `sqlserver2,1434`. That is the host-mapped port, whereas container-to-container SQL traffic uses `sqlserver2,1433`. Review/correct the `@secondary_server` value in `sql/log_shipping_primary.sh` and keep the SQL Server names used by log-shipping metadata consistent before relying on monitoring results.
- Generated backup/copy/restore schedule names are reused across databases. When using counts greater than one, inspect job-to-schedule associations and job history for every database rather than assuming that all jobs have working schedules.
- Jobs require SQL Server Agent, the shared directories, and a valid FULL-recovery log-backup chain. Setup runs SQL statements without stopping reliably on errors; validate both configuration and actual scheduled execution.

### Other operational limits

- **Initialization is not idempotent.** It creates logins, keys, certificates, endpoints, databases, groups, and jobs without comprehensive existence checks. The DACPAC database-existence check is a limited exception.
- **Readiness and waits are basic.** Increase `INIT_WAIT` for slow hosts. Marker/certificate polling has no timeout, and SQL failures can still be followed by marker-file creation. A stalled earlier workflow can block later workflows.
- **Build inputs are mutable and partly legacy.** Both images use `*-latest`, fetch the latest SqlPackage, and install a specific old OpenSSL `.deb` over HTTP. The 2019 Dockerfile also requires `libicu66`. Package availability and runtime compatibility can change; a build failure may require updating or pinning the Dockerfile dependencies.
- **The lab shares one failure domain.** There is no external cluster manager, witness, AG listener, automated failover orchestration, or failover/failback script. Initial roles and names are hardcoded. Consult the relevant SQL Server procedures before experimenting with role changes; rerunning initialization does not handle failover.
- **Credentials and ports are for a controlled lab.** Passwords are stored in Compose, endpoint setup reuses the password, and published SQL ports have no host-IP restriction. Bind ports to `127.0.0.1` (for example, `"127.0.0.1:1433:1433"`) if access should be limited to the Docker host.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| Container exits during SQL startup | `docker compose logs sqlserver1 sqlserver2`; password validity, available memory, CPU architecture, and EULA acceptance |
| Port or container name already in use | Stop the other version's lab or conflicting service; adjust host ports if necessary. Renaming container/SQL host names also requires script changes |
| `sqlcmd: No such file or directory` | Verify `/opt/mssql-tools/bin/` versus `/opt/mssql-tools18/bin/` in the image, including `install_dacpac.sh` |
| SQL client reports an untrusted certificate | Use `-C` for local-lab `sqlcmd` connections; review SqlPackage's separate trust option |
| Repeated certificate/marker waiting messages | Confirm both services are running, inspect earlier SQL errors, apply the shared-directory correction, and reset the lab |
| Log backup cannot open its destination | Confirm `/sql_files/ls_backups` and `/sql_files/ls_copies` exist and are writable; apply the cleanup correction |
| Log backup says recovery model is SIMPLE | Check `sys.databases.recovery_model_desc`; mirroring/log-shipping scripts require FULL recovery but do not set it explicitly |
| Database or endpoint already exists | Initialization reran against existing state; use a fresh lab, or implement existence checks before preserving state |
| AG database missing on secondary | Check both replicas' SQL errors, endpoint connectivity, available memory/disk, and automatic-seeding state; verify the target name was not already created by DACPAC installation |
| DACPAC changes did not appear | Check the filename under `sql/dacpac/`, rebuild, inspect publish errors, and remember startup skips existing databases |
| Log shipping configured but no new data arrives | Inspect Agent job history and schedules, backup/copy directories, recovery model, and server-name/port metadata |
| Dockerfile package install or SqlPackage launch fails | Review the current base image against the Dockerfile's legacy OS/library dependencies and unpinned download |

Useful diagnostics:

```bash
docker compose ps -a
docker compose logs --tail=200 sqlserver1 sqlserver2
docker compose exec sqlserver1 ls -la /sql_files
docker compose exec sqlserver2 ls -la /sql_files
```

Do not treat shared marker files as proof of SQL success. Use the SQL state and job-history queries above.

## Repository layout

```text
README.md
SQLServer_2019/
  docker-compose.yml
  sql/
    dockerfile                  # Image build, SQL settings, SqlPackage installation
    entrypoint.sh               # Starts initialization alongside SQL Server
    db-init.sh                  # Orchestrates all optional workflows
    common_sqlserver1.sh        # Primary endpoint/certificate/login setup
    common_sqlserver2.sh        # Secondary endpoint/certificate/login setup
    install_dacpac.sh           # Conditional local DACPAC publish
    mirroring_primary.sh
    mirroring_secondary.sh
    ag_primary.sh
    ag_secondary.sh
    log_shipping_primary.sh
    log_shipping_secondary.sh
    dacpac/                     # Create this directory for your own packages
SQLServer_2022/                  # Same layout, 2022 base image and client changes
```

The two version trees are independent copies. Apply customizations and any setup corrections to the version you build; changes in one tree do not propagate to the other.
