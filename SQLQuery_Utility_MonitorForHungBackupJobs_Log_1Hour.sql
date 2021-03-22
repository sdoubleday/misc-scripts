USE msdb
go

/*Put this into a SEPARATE job from the backups -- Possibly on the same schedule, or maybe 
twice as often (depends on your paranoia level, duration of backups, frequency, et cetera.
Then configure it to email you if it fails. It checks for recent backups and throws an error
if you don't have them -- this is good for catching hung backups jobs, which are basically
silent failures.

Needs optional exclusions list for databases.
*/

DECLARE @BackupType CHAR(1) = 'L' /*D (for database), L (for log), or I (for differential)*/
DECLARE @Hours INT = 1 /*Time that can pass before we want to fail the job to be notified*/
DECLARE @Success BIT = 0
;WITH myExcludedDatabases AS ( SELECT name FROM (VALUES ('-999999')) AS exclusions (name))


, myBackups AS(
select 
 @@SERVERNAME AS Servername
,databases.name
,databases.create_date
,databases.recovery_model_desc
,BackupInfo.backup_start_date AS MostRecentBackupStartDate
,BackupInfo.backup_finish_date AS MostRecentBackupFinishDate
,BackupInfo.type AS MostRecentBackupType
,BackupInfo.Physical_Device_Directory
,BackupInfo.physical_device_name
,BackupInfo.backup_size
,CONVERT(numeric(32, 4), BackupInfo.backup_size) / 1048576.0 AS SizeInMB
,CONVERT(numeric(32, 4), BackupInfo.backup_size) / 1024.0 / 1024.0 / 1024.0 AS SizeInGB
FROM sys.databases
OUTER APPLY (
	SELECT TOP 1
	backupset.*
	,mf.physical_device_name
	,SUBSTRING(mf.physical_device_name, 0, LEN(mf.physical_device_name) - CHARINDEX ('\', REVERSE(mf.physical_device_name), 1) + 1) as Physical_Device_Directory
	FROM msdb.dbo.backupset
	INNER JOIN msdb.dbo.backupmediafamily mf
	on backupset.media_set_id = mf.media_set_id
	WHERE backupset.database_name = databases.name
	and backupset.type = @BackupType
	AND backupset.backup_finish_date > DATEADD(HOUR,- @Hours, GETDATE())
	ORDER BY backupset.backup_set_id DESC /*Most Recent*/
) AS BackupInfo
LEFT OUTER JOIN myExcludedDatabases
ON databases.name = myExcludedDatabases.name
WHERE databases.name NOT LIKE 'tempdb'
AND myExcludedDatabases.name IS NULL
AND 
(
	@BackupType = 'D' OR databases.name NOT LIKE 'master' /*Master can only have full backups*/
)

)

SELECT @Success = CASE WHEN COUNT(mybackups.MostRecentBackupType) = COUNT(1)
THEN 1 ELSE 0 END FROM myBackups

DECLARE @BackupTypeText NVARCHAR(100) = CASE WHEN @BackupType = 'D' THEN 'Database'
	WHEN @BackupType = 'L' THEN 'Log'
	WHEN @BackupType = 'I' THEN 'Differential'
	ELSE 'Error - bad monitoring script configuration.'
END

IF @Success = 0 
BEGIN
	DECLARE @ErrorSeverity	 INT = 11
	Declare @ErrorState		 INT = 1
	DECLARE @ErrorMessage	 NVARCHAR(4000) = N'User defined error - Most Recent ' + @BackupTypeText + N' is more than ' + Cast(@Hours AS NVARCHAR(100)) + N' hour(s) ago.'

	RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState)
END