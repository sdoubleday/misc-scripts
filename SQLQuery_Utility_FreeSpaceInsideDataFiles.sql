/*2015-02-06
sdoubleday
Requires permissions to all databases, or will crap out partway through

Based on: https://social.msdn.microsoft.com/Forums/sqlserver/en-US/009ddb4e-4ba8-4fa9-8696-28edf8a5de2b/query-for-full-drives?forum=sqlgetstarted

Cycles through databases checking space used.
*/
USE master
GO
IF OBJECT_ID('tempDB..#SpaceInsideDatabaseFiles') IS NOT NULL
BEGIN
	DROP TABLE #SpaceInsideDatabaseFiles
END
GO

CREATE TABLE #SpaceInsideDatabaseFiles (
	 [DatabaseName] sysname
	,[Segment Name] sysname
	,[Group ID] INT
	,[File Name] NVARCHAR(4000)
	,[Size in MB] Decimal(19,4)
	,[Space Used in MB] Decimal(19,4)
	,[Available Space in MB] Decimal(19,4)
	,[Percent Used] Decimal(19,4)
	)

DECLARE myDBs CURSOR FOR 
SELECT 
N'USE ' + Name + N'

INSERT INTO #SpaceInsideDatabaseFiles
SELECT db_name() AS [DatabaseName]
	,RTRIM(name) AS [Segment Name]
	, groupid AS [Group Id]
	, filename AS [File Name],
   CAST(size/128.0 AS DECIMAL(10,2)) AS [Size in MB],
   CAST(FILEPROPERTY(name, ''SpaceUsed'')/128.0 AS DECIMAL(10,2)) AS [Space Used in MB],
   CAST(size/128.0-(FILEPROPERTY(name, ''SpaceUsed'')/128.0) AS DECIMAL(10,2)) AS [Available Space in MB],
   CAST((CAST(FILEPROPERTY(name, ''SpaceUsed'')/128.0 AS DECIMAL(10,2))/CAST(size/128.0 AS DECIMAL(10,2)))*100 AS DECIMAL(10,2)) AS [Percent Used]
FROM sys.sysfiles'

AS myQuery from sys.databases ORDER BY name desc

OPEN myDBs

DECLARE @mySQL NVARCHAR(4000)
FETCH NEXT FROM myDBs INTO @mySQL
WHILE @@FETCH_STATUS = 0
BEGIN
	EXECUTE sp_executesql @mySQL
	FETCH NEXT FROM myDBs INTO @mySQL
END


CLOSE myDBs
DEALLOCATE myDBs

USE master
GO

SELECT * FROM #SpaceInsideDatabaseFiles