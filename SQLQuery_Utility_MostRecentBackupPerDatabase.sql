USE msdb
go

/*
sdoubleday 2016-04-06
Uncomment one of these, as needed.
Square brackets in a like statement are "Any of these."*/

--DECLARE @BackupTypes NVARCHAR(50) = 'D' /*Full Database Backups*/
--DECLARE @BackupTypes NVARCHAR(50) = 'I' /*Differential Database Backups*/
--DECLARE @BackupTypes NVARCHAR(50) = 'L' /*Transaction Log Backups (data from the .ldf log file - allows for .ldf file space reuse)*/
--DECLARE @BackupTypes NVARCHAR(50) = '[DI]' /*Data Backups (Full and Diff both backup data from .mdf and .ndf files)*/
DECLARE @BackupTypes NVARCHAR(50) = '[DIL]' /*Any type of backup (Don't get cocky and just use this)*/
--DECLARE @BackupTypes NVARCHAR(50) = '[IL]' /*For completeness, the odd case of Differential or Transaction log backups.*/

Declare @IncludeCopyOnlyBackups BIT = 0 /*Rare case - change to 1.*/

select 
 backupinfo.server_name /*Note that a database must be listed in the backup set for a restore to run. Thus, a restore will ADD the most recent backup record from the source server, if it isn't there.*/
,databases.name
,databases.recovery_model_desc
,BackupInfo.type AS MostRecentBackupType
/*,BackupInfo.backup_start_date AS MostRecentBackupStartDate*/
,BackupInfo.backup_finish_date AS MostRecentBackupFinishDate
,CAST(DATEDIFF(Second, BackupInfo.backup_start_date ,BackupInfo.backup_finish_date ) AS decimal(19,4)) / 60.0 AS Duration_Minutes /*Calculation rounds roughly, but is close enough.*/
,CONVERT(numeric(32, 4), BackupInfo.backup_size) / 1024.0 / 1024.0 / 1024.0 AS SizeInGB
,BackupInfo.Physical_Device_Directory
/*,BackupInfo.physical_device_name*/
/*,BackupInfo.backup_size*/
/*,CONVERT(numeric(32, 4), BackupInfo.backup_size) / 1048576.0 AS SizeInMB*/
,BackupInfo.is_copy_only
,databases.create_date AS DatabaseCreateDate
/*2008 R2 and later*/
,CONVERT(numeric(32, 4), BackupInfo.compressed_backup_size) / 1024.0 / 1024.0 / 1024.0 AS CompressedSizeInGB
,logical_device_name
,Device_Type
,Max_family_sequence_number
FROM sys.databases
OUTER APPLY (
SELECT TOP 1 /*Edit this line to add more results!*/
backupset.*
,mf.physical_device_name
,SUBSTRING(mf.physical_device_name, 0, LEN(mf.physical_device_name) - CHARINDEX ('\', REVERSE(mf.physical_device_name), 1) + 1) as Physical_Device_Directory
,mf.logical_device_name
,CASE mf.device_type 
	WHEN NULL THEN 'Null device Type'
	WHEN 2 THEN 'Disk'
	WHEN 5 THEN 'Tape'
	WHEN 7 THEN 'Virtual Device'
	WHEN 105 THEN 'Permanent Backup Device'
	ELSE 'Unknown - device_type number is: ' + CAST(mf.device_type AS VARCHAR(50))
END AS Device_Type
,mf.family_sequence_number AS Max_family_sequence_number
FROM msdb.dbo.backupset
CROSS APPLY (
	SELECT TOP 1 * FROM msdb.dbo.backupmediafamily bmf
	WHERE backupset.media_set_id = bmf.media_set_id
	ORDER BY bmf.family_sequence_number DESC
) AS mf /*In case you have multiple media elements in the media family, we are only getting one*/
WHERE backupset.database_name = databases.name
and backupset.type LIKE @BackupTypes
and backupset.is_copy_only = @IncludeCopyOnlyBackups
ORDER BY backupset.backup_set_id DESC /*Most Recent*/
) AS BackupInfo
/*Enable this to filter by db name!*/
/* 
Where database_name like 'database'
*/
