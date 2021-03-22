/*
https://www.mssqltips.com/sqlservertip/1525/scan-a-sql-server-database-for-objects-and-columns-containing-a-given-text-value/
*/

/*CREATE PROCEDURE dbo.usp_ScanAllColumnsForValue (*/
DECLARE @ScanValue_Exact VARCHAR(100)				=	''
DECLARE @Optional_PartialColumnName VARCHAR(100)	=	''
DECLARE @Optional_PartialTableName VARCHAR(100)		=	''
/*)
AS*/
/*I further refined my column scan to ignore date, timestamp columns, and UniqueIdentifier columns
*/

DECLARE @FragmentOfColumnName_ForScan VARCHAR(100) = @Optional_PartialColumnName
DECLARE @WholeTableName_ForScan VARCHAR(100) = '%' + @Optional_PartialTableName + '%'
DECLARE @DistinctColumnValueFilter VARCHAR(100) = @ScanValue_Exact

IF OBJECT_ID('tempdb..#TableOfMyStuff') IS NOT NULL
BEGIN
DROP TABLE #TableOfMyStuff
END


SET NOCOUNT ON

DECLARE @myThing VARCHAR(500) 
DECLARE @mySchema VARCHAR(500)
DECLARE @myColumn VARCHAR(500)
DECLARE @myData_Type VARCHAR(500)
DECLARE @query NVARCHAR(2000)
DECLARE @Indicator INT
DECLARE @i Decimal(19,4) = 1

CREATE TABLE #TableOfMyStuff (CountOfRecords INT, MyDistinctValue VARCHAR(1000), Column_Name SYSNAME, Table_Name SYSNAME, Table_Schema SYSNAME, Data_Type SYSNAME)

DECLARE myCursor CURSOR FOR 
	SELECT DISTINCT table_name, table_schema, column_name, Data_Type from information_schema.columns 
	where column_name like '%' + @FragmentOfColumnName_ForScan + '%' AND table_name LIKE @wholeTableName_ForScan
	AND Data_Type <> 'text'
	AND Data_Type <> 'ntext'
	AND Data_Type <> 'image'
	AND Data_Type NOT LIKE 'Date%'
	AND Data_Type NOT LIKE 'timestamp'
	AND Data_Type NOT LIKE 'UniqueIdentifier'
	AND COALESCE(CHARACTER_MAXIMUM_LENGTH, 0) <> -1 /*Length MAX throws errors. 
		Consider casting as length 8000 for VARCHAR and 4000 for NVARCHAR. Will require further mods.*/

OPEN myCursor
FETCH NEXT FROM myCursor INTO @myThing, @mySchema, @myColumn, @myData_Type

WHILE(@@FETCH_STATUS = 0)
BEGIN 

SET XACT_Abort ON;
/*This will cause execution to bail out after one error. It WILL fire the catch block.
It will also close the transaction, which is important if you hit a validation error,
such as if a table has changed or been dropped - otherwise you can wind up with open transactions*/


BEGIN TRY

set @query = 'INSERT INTO #TableOfMyStuff SELECT COUNT(1), [' + @myColumn + '], ''' + @myColumn + ''' AS Column_Name, ''' + @myThing + ''' AS Table_Name, ''' + @mySchema + ''' AS Table_Schema, ''' + @myData_Type + ''' AS Data_Type FROM [' + @mySchema + '].['+ @myThing + '] GROUP BY [' + @myColumn + ']'
exec sp_executesql @query

SELECT @Indicator = COUNT(1) FROM 
(
	SELECT a.CountOfRecords
	,a.MyDistinctValue
	,a.Column_Name
	,a.Table_Name
	,a.Table_Schema
	,a.Data_Type
	FROM #TableOfMyStuff a
	where 
	a.Data_Type NOT LIKE 'UniqueIdentifier'

) AS myData

WHERE myData.MyDistinctValue like @DistinctColumnValueFilter

IF(@Indicator > 0) 
BEGIN
	SELECT * FROM 
	(
		SELECT a.CountOfRecords
		,a.MyDistinctValue
		,a.Column_Name
		,a.Table_Name
		,a.Table_Schema
		,a.Data_Type
		FROM #TableOfMyStuff a
		where 
		a.Data_Type NOT LIKE 'UniqueIdentifier'

	) AS myData

	WHERE myData.MyDistinctValue like @DistinctColumnValueFilter

	ORDER BY Table_Schema, Table_Name, Column_Name DESC

END	

TRUNCATE TABLE #TableOfMyStuff;

END TRY


BEGIN CATCH 
	DECLARE 
	 @ErrorNumber	 INT
	,@ErrorSeverity	 INT
	,@ErrorState	 INT
	,@ErrorProcedure	 NVARCHAR(4000)
	,@ErrorLine		 INT
	,@ErrorMessage	 NVARCHAR(4000)

	SELECT
		@ErrorNumber	= ERROR_NUMBER() ,
		@ErrorSeverity	= ERROR_SEVERITY() ,
		@ErrorState		= ERROR_STATE() ,
		@ErrorProcedure = ERROR_PROCEDURE() ,
		@ErrorLine		= ERROR_LINE() ,
		@ErrorMessage	= ERROR_MESSAGE() +  @query;
	
	RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState, @ErrorNumber,@ErrorLine)
	ROLLBACK TRANSACTION
END CATCH

FETCH NEXT FROM myCursor INTO @myThing, @mySchema, @myColumn, @myData_Type

IF (@i % 100 = 0)
PRINT 'Percent Complete: ' + CAST((@i/CAST(@@CURSOR_ROWS AS Decimal(19,4)) * 100.0 ) AS VARCHAR(1000))
SET @i += 1


END /*End While*/
CLOSE myCursor
DEALLOCATE myCursor


