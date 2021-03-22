/*
Script to check disk space for databases
http://blog.sqlauthority.com/2013/08/02/sql-server-disk-space-monitoring-detecting-low-disk-space-on-server/
*/

SELECT DISTINCT DB_NAME(dovs.database_id) DBName,
dovs.logical_volume_name AS LogicalName,
dovs.volume_mount_point AS Drive,
CONVERT(INT,dovs.available_bytes/1048576.0) AS FreeSpaceInMB
,CONVERT(INT,dovs.total_bytes/1048576.0) AS TotalSpaceInMB
,CONVERT(decimal(19,4),dovs.available_bytes/1048576.0) /
CONVERT(decimal(19,4),dovs.total_bytes/1048576.0) * 100.00 AS PercentSpaceFree

FROM sys.master_files mf
CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.FILE_ID) dovs
ORDER BY FreeSpaceInMB ASC
GO

SELECT DISTINCT 
dovs.logical_volume_name AS LogicalName,
dovs.volume_mount_point AS Drive,
CONVERT(INT,dovs.available_bytes/1048576.0) AS FreeSpaceInMB
,CONVERT(INT,dovs.total_bytes/1048576.0) AS TotalSpaceInMB
,CONVERT(decimal(19,4),dovs.available_bytes/1048576.0) /
CONVERT(decimal(19,4),dovs.total_bytes/1048576.0) * 100.00 AS PercentSpaceFree
,GetDate() AS TimeStamp
,@@ServerName AS ServerName

FROM sys.master_files mf
CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.FILE_ID) dovs
ORDER BY FreeSpaceInMB ASC
Go
