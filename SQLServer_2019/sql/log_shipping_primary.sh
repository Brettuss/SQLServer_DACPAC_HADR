i=1
while [ $i -le $NUM_OF_LOG_SHIPPING_DATABASES ]
do
	if [ $NUM_OF_LOG_SHIPPING_DATABASES -eq 1 ] 
	then
		i=
	fi

	/opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -q "CREATE DATABASE [$LOG_SHIPPING_DATABASE_NAME$i]"
	/opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d $LOG_SHIPPING_DATABASE_NAME$i -Q "BACKUP DATABASE [$LOG_SHIPPING_DATABASE_NAME$i] TO DISK = '/sql_files/ls_backups/$LOG_SHIPPING_DATABASE_NAME$i.bak'"
	/opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d $LOG_SHIPPING_DATABASE_NAME$i -Q "BACKUP LOG [$LOG_SHIPPING_DATABASE_NAME$i] TO DISK = '/sql_files/ls_backups/$LOG_SHIPPING_DATABASE_NAME$i.trn'"
	if [ $NUM_OF_LOG_SHIPPING_DATABASES -eq 1 ] 
	then
		i=1
	fi
	
	i=$((i + 1))
done

echo "backups are done" > /sql_files/ls_backups_done.txt

i=1
while [ $i -le $NUM_OF_LOG_SHIPPING_DATABASES ]
do
	if [ $NUM_OF_LOG_SHIPPING_DATABASES -eq 1 ] 
	then
		i=
	fi
	echo "Begin - PRIMARY - Setting up Log Shipping for database $LOG_SHIPPING_DATABASE_NAME$i"

	/opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d $LOG_SHIPPING_DATABASE_NAME$i -Q "DECLARE @LS_BackupJobId AS uniqueidentifier 
	DECLARE @LS_PrimaryId	AS uniqueidentifier 
	DECLARE @SP_Add_RetCode	As int 

	EXEC @SP_Add_RetCode = master.dbo.sp_add_log_shipping_primary_database 
			@database = N'$LOG_SHIPPING_DATABASE_NAME$i' 
			,@backup_directory = N'/sql_files/ls_backups' 
			,@backup_share = N'/sql_files/ls_backups' 
			,@backup_job_name = N'LSBackup_$LOG_SHIPPING_DATABASE_NAME$i' 
			,@backup_retention_period = 4320
			,@backup_compression = 2
			,@backup_threshold = 60 
			,@threshold_alert_enabled = 1
			,@history_retention_period = 5760 
			,@backup_job_id = @LS_BackupJobId OUTPUT 
			,@primary_id = @LS_PrimaryId OUTPUT 
			,@overwrite = 1 


	IF (@@ERROR = 0 AND @SP_Add_RetCode = 0) 
	BEGIN 

	DECLARE @LS_BackUpScheduleUID	As uniqueidentifier 
	DECLARE @LS_BackUpScheduleID	AS int 


	EXEC msdb.dbo.sp_add_schedule 
			@schedule_name =N'LSBackupSchedule_sqlserver2,14331' 
			,@enabled = 1 
			,@freq_type = 4 
			,@freq_interval = 1 
			,@freq_subday_type = 4 
			,@freq_subday_interval = 15 
			,@freq_recurrence_factor = 0 
			,@active_start_date = 20211010 
			,@active_end_date = 99991231 
			,@active_start_time = 0 
			,@active_end_time = 235900 
			,@schedule_uid = @LS_BackUpScheduleUID OUTPUT 
			,@schedule_id = @LS_BackUpScheduleID OUTPUT 

	EXEC msdb.dbo.sp_attach_schedule 
			@job_id = @LS_BackupJobId 
			,@schedule_id = @LS_BackUpScheduleID  

	EXEC msdb.dbo.sp_update_job 
			@job_id = @LS_BackupJobId 
			,@enabled = 1 


	END 


	EXEC master.dbo.sp_add_log_shipping_alert_job 

	EXEC master.dbo.sp_add_log_shipping_primary_secondary 
			@primary_database = N'$LOG_SHIPPING_DATABASE_NAME$i' 
			,@secondary_server = N'sqlserver2,1434' 
			,@secondary_database = N'$LOG_SHIPPING_DATABASE_NAME$i' 
			,@overwrite = 1"

	echo "END - PRIMARY - Setting up Log Shipping for database $LOG_SHIPPING_DATABASE_NAME$i"

	if [ $NUM_OF_LOG_SHIPPING_DATABASES -eq 1 ] 
	then
		i=1
	fi
	
	i=$((i + 1))

done

echo "ls done" > /sql_files/ls_primary_complete.txt