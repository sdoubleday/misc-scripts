
/*sdoubleday 2015-02-03
This is useful for determining if we have a log file reuse problem, and if so, whether or not we care.
I filtered this to remove databases in SIMPLE model.
*/

;with MyLogSizes AS (
select 
 master_files.database_id
,databases.name
,databases.recovery_model_desc
,count(1) AS CountOfNonLogFiles
,SUM(SIZE)/1024.0* 8.0 AS SizeInMB
,SUM(SIZE) /1024.0/1024.0 * 8.0 as SizeInGB
from sys.master_files 
INNER JOIN sys.databases
on master_files.database_id = databases.database_id
WHERE Type = 1
GROUP BY master_files.database_id
,databases.name
,databases.recovery_model_desc
)

select 
 master_files.database_id
,databases.name
,databases.recovery_model_desc
,databases.[log_reuse_wait_desc]
,count(1) AS CountOfNonLogFiles
,SUM(SIZE)/1024.0* 8.0 AS SizeInMB
,SUM(SIZE) /1024.0/1024.0 * 8.0 as SizeInGB
,MyLogSizes.SizeInMB AS SizeInMB_Log
,MyLogSizes.SizeInGB AS SizeInGB_Log
,MyLogSizes.SizeInMB / ( SUM(SIZE)/1024.0 * 8.0 ) * 100.0 AS LogAsPercentageOfOtherFiles
from sys.master_files 
INNER JOIN sys.databases
on master_files.database_id = databases.database_id
INNER JOIN MyLogSizes
ON MyLogSizes.database_id = databases.database_id
WHERE master_files.Type <> 1
AND databases.recovery_model_desc NOT LIKE 'SIMPLE'
GROUP BY master_files.database_id
,databases.name
,databases.recovery_model_desc
,MyLogSizes.SizeInMB 
,MyLogSizes.SizeInGB 
,databases.[log_reuse_wait_desc]