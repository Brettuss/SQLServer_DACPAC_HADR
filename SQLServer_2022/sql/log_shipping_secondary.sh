while [ ! -f /sql_files/ls_backups_done.txt ]
do
  echo "Waiting for log shipping backups to run."
  sleep 2
done 

i=1
while [ $i -le $NUM_OF_LOG_SHIPPING_DATABASES ]
do
	if [ $NUM_OF_LOG_SHIPPING_DATABASES -eq 1 ] 
	then
		i=
	fi

	/opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "RESTORE DATABASE [$LOG_SHIPPING_DATABASE_NAME$i] FROM DISK = N'/sql_files/ls_backups/$LOG_SHIPPING_DATABASE_NAME$i.bak' WITH NORECOVERY"
	/opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "RESTORE LOG [$LOG_SHIPPING_DATABASE_NAME$i] FROM DISK = N'/sql_files/ls_backups/$LOG_SHIPPING_DATABASE_NAME$i.trn' WITH NORECOVERY"

	if [ $NUM_OF_LOG_SHIPPING_DATABASES -eq 1 ] 
	then
		i=1
	fi
	
	i=$((i + 1))

done

# Wait until log shipping is setup on primary
while [ ! -f /sql_files/ls_primary_complete.txt ]
do
  echo "Waiting for log shipping setup on primary to complete."
  sleep 2
done 

i=1
while [ $i -le $NUM_OF_LOG_SHIPPING_DATABASES ]
do
	if [ $NUM_OF_LOG_SHIPPING_DATABASES -eq 1 ] 
	then
		i=
	fi

	echo "Begin - SECONDARY - Setting up Log Shipping for $LOG_SHIPPING_DATABASE_NAME$i"
	
	/opt/mssql-tools/bin/sqlcmd -U sa -P $SA_PASSWORD -d master -q "DECLARE @LS_Secondary__CopyJobId	AS uniqueidentifier 
	DECLARE @LS_Secondary__RestoreJobId	AS uniqueidentifier 
	DECLARE @LS_Secondary__SecondaryId	AS uniqueidentifier 
	DECLARE @LS_Add_RetCode	As int 


	EXEC @LS_Add_RetCode = master.dbo.sp_add_log_shipping_secondary_primary 
			@primary_server = N'sqlserver1,1433' 
			,@primary_database = N'$LOG_SHIPPING_DATABASE_NAME$i' 
			,@backup_source_directory = N'/sql_files/ls_backups' 
			,@backup_destination_directory = N'/sql_files/ls_copies' 
			,@copy_job_name = N'LSCopy_sqlserver1,1433_$LOG_SHIPPING_DATABASE_NAME$i' 
			,@restore_job_name = N'LSRestore_sqlserver1,1433_$LOG_SHIPPING_DATABASE_NAME$i' 
			,@file_retention_period = 4320 
			,@overwrite = 1 
			,@copy_job_id = @LS_Secondary__CopyJobId OUTPUT 
			,@restore_job_id = @LS_Secondary__RestoreJobId OUTPUT 
			,@secondary_id = @LS_Secondary__SecondaryId OUTPUT 

	IF (@@ERROR = 0 AND @LS_Add_RetCode = 0) 
	BEGIN 

	DECLARE @LS_SecondaryCopyJobScheduleUID	As uniqueidentifier 
	DECLARE @LS_SecondaryCopyJobScheduleID	AS int 


	EXEC msdb.dbo.sp_add_schedule 
			@schedule_name =N'DefaultCopyJobSchedule' 
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
			,@schedule_uid = @LS_SecondaryCopyJobScheduleUID OUTPUT 
			,@schedule_id = @LS_SecondaryCopyJobScheduleID OUTPUT 

	EXEC msdb.dbo.sp_attach_schedule 
			@job_id = @LS_Secondary__CopyJobId 
			,@schedule_id = @LS_SecondaryCopyJobScheduleID  

	DECLARE @LS_SecondaryRestoreJobScheduleUID	As uniqueidentifier 
	DECLARE @LS_SecondaryRestoreJobScheduleID	AS int 


	EXEC msdb.dbo.sp_add_schedule 
			@schedule_name =N'DefaultRestoreJobSchedule' 
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
			,@schedule_uid = @LS_SecondaryRestoreJobScheduleUID OUTPUT 
			,@schedule_id = @LS_SecondaryRestoreJobScheduleID OUTPUT 

	EXEC msdb.dbo.sp_attach_schedule 
			@job_id = @LS_Secondary__RestoreJobId 
			,@schedule_id = @LS_SecondaryRestoreJobScheduleID  


	END 


	DECLARE @LS_Add_RetCode2	As int 


	IF (@@ERROR = 0 AND @LS_Add_RetCode = 0) 
	BEGIN 

	EXEC @LS_Add_RetCode2 = master.dbo.sp_add_log_shipping_secondary_database 
			@secondary_database = N'$LOG_SHIPPING_DATABASE_NAME$i' 
			,@primary_server = N'sqlserver1,1433' 
			,@primary_database = N'$LOG_SHIPPING_DATABASE_NAME$i' 
			,@restore_delay = 0 
			,@restore_mode = 0 
			,@disconnect_users	= 0 
			,@restore_threshold = 45   
			,@threshold_alert_enabled = 1 
			,@history_retention_period	= 5760 
			,@overwrite = 1 

	END 


	IF (@@error = 0 AND @LS_Add_RetCode = 0) 
	BEGIN 

	EXEC msdb.dbo.sp_update_job 
			@job_id = @LS_Secondary__CopyJobId 
			,@enabled = 1 

	EXEC msdb.dbo.sp_update_job 
			@job_id = @LS_Secondary__RestoreJobId 
			,@enabled = 1 

	END"

	if [ $NUM_OF_LOG_SHIPPING_DATABASES -eq 1 ] 
	then
		i=1
	fi

	echo "End - SECONDARY - Setting up Log Shipping for $LOG_SHIPPING_DATABASE_NAME$i"
	
	i=$((i + 1))

done