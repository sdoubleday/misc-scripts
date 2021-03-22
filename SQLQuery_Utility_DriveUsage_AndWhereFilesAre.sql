/*
https://social.msdn.microsoft.com/Forums/sqlserver/en-US/009ddb4e-4ba8-4fa9-8696-28edf8a5de2b/query-for-full-drives?forum=sqlgetstarted
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
