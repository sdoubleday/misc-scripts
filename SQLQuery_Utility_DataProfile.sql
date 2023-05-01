CREATE PROCEDURE dbo.sp_dataprofile

 @Table_Name NVARCHAR(128) = N'ReplaceMe'
,@ColumnListFilter NVARCHAR(4000) = NULL /* 'This,CommaSeparatedList,%Allows,Wild%,Card%Search' */
,@Rerun BIT = 0
,@Table_Schema NVARCHAR(128) = N'dbo'

,@DecimalCutoffForLowCardinality_DistinctOverCount NVARCHAR(128) = N'0.0001'
,@DecimalCutoffForMediumCardinality_DistinctOverCount NVARCHAR(128) = N'0.001'

,@DestinationDatabase SYSNAME = 'tempdb' /*We are creating tables in tempdb - sure, they vanish on reboot, and if you don't want that, redirect this.*/
,@DestinationSchema SYSNAME = 'dbo'

,@help BIT = 0
AS

IF @help = 1
BEGIN
PRINT 'Runs a data profile of the target table. Saves it, by default, to a table in tempdb (that does not persist past a restart of SQL Server).';
PRINT 'Specify @Rerun = 1 to re-profile the table, if the profile already exists.';
PRINT 'Specify @ColumnListFilter = ''CommaSeparatedList,%Allows,Wild%,Card%Search'' to get back a subset of columns.';
PRINT '';
PRINT 'EXECUTE dbo.sp_dataprofile ''yourtable'';';
PRINT 'EXECUTE dbo.sp_dataprofile ''yourtable'', ''%ID'' /*just columns that end with ID*/;';
PRINT 'EXECUTE dbo.sp_dataprofile ''yourtable'', @Rerun = 1 /*if the data changed since last time*/;';
PRINT 'EXECUTE dbo.sp_dataprofile ''yourtable'', @Table_Schema = ''yourShema'';';
RETURN;
END

DECLARE @OutputTable NVARCHAR(128) = @DestinationDatabase + N'.' + @DestinationSchema + N'.DataProfile_' + @Table_Schema + N'_' + @Table_Name;

IF OBJECT_ID(@OutputTable) IS NULL
BEGIN
    SET @Rerun = 1;
END

DECLARE @SQL NVARCHAR(4000) = '';
DECLARE myCursor CURSOR FOR
SELECT 
'CREATE TABLE ' + @OutputTable + '
(
     COLUMN_NAME SYSNAME NOT NULL
    ,DATA_TYPE SYSNAME NOT NULL
    ,ORDINAL_POSITION INT NOT NULL
    ,MaxValue NVARCHAR(500) NULL
    ,MinValue NVARCHAR(500) NULL
    ,CountValue BIGINT NOT NULL
    ,DistinctCount BIGINT NOT NULL
    ,CountNulls BIGINT NOT NULL
    ,dataProfileID INT NOT NULL

    ,dataProfileDate DATETIME2(7) NOT NULL DEFAULT (SYSDATETIME())
    ,SimpleDataClassification AS CASE WHEN DistinctCount = 2 THEN ''Binary-Y/N-True/False''
        WHEN DistinctCount = 0 AND CountNulls = 0 THEN ''Empty Table''
        WHEN DistinctCount = 0 AND CountNulls > 0 THEN ''All Nulls''
        WHEN DistinctCount = 1 AND CountNulls > 0 THEN ''Unary With Nulls''
        WHEN DistinctCount = 1 AND CountNulls = 0 THEN ''Same Value Everywhere''
        WHEN DistinctCount = CountValue AND CountNulls = 0 THEN ''Unique Per Row''
        WHEN DistinctCount = CountValue AND CountNulls > 0 THEN ''Unique Where Not Null''
        WHEN DATA_TYPE = ''UNIQUEIDENTIFIER'' THEN ''DATA_TYPE UNIQUEIDENTIFIER''
        WHEN DATA_TYPE LIKE ''DATE'' THEN ''DATA_TYPE Date''
        WHEN DATA_TYPE LIKE ''TIME'' THEN ''DATA_TYPE Time''
        WHEN DATA_TYPE LIKE ''%DATE%''  THEN ''DATA_TYPE DateTime''
        WHEN CAST(DistinctCount AS DECIMAL(19,10)) / CountValue < ' + @DecimalCutoffForLowCardinality_DistinctOverCount + ' THEN ''Low Cardinality''
        WHEN CAST(DistinctCount AS DECIMAL(19,10)) / CountValue < ' + @DecimalCutoffForMediumCardinality_DistinctOverCount + ' THEN ''Medium Cardinality''
    END

);'
WHERE OBJECT_ID(@OutputTable,'U') IS NULL
AND @Rerun = 1

UNION ALL

SELECT
'INSERT INTO ' + @OutputTable + ' SELECT ''' + COLUMN_NAME + ''' AS COLUMN_NAME' +
',''' + DATA_TYPE + ''' AS DATA_TYPE' +
',' + CAST(ORDINAL_POSITION AS NVARCHAR(4000)) + ' AS ORDINAL_POSITION' +
', CAST(MAX([' + COLUMN_NAME + ']) AS NVARCHAR(500) ) AS MaxValue' +
', CAST(MIN([' + COLUMN_NAME + ']) AS NVARCHAR(500) ) AS MinValue' +
', COUNT([' + COLUMN_NAME + ']) AS CountValue' +
', COUNT(DISTINCT [' + COLUMN_NAME + ']) AS DistinctCount' +
', COUNT( CASE WHEN [' + COLUMN_NAME + '] IS NULL THEN 1 ELSE NULL END) AS CountNulls' +
', (SELECT COUNT(1) + 1 FROM ' + @OutputTable + ' WHERE COLUMN_NAME = ''' + COLUMN_NAME + ''') AS dataProfileID' +
', SYSDATETIME() AS dataProfileDate' +
' FROM [' + TABLE_SCHEMA + '].[' + TABLE_NAME + '];'
FROM INFORMATION_SCHEMA.COLUMNS
WHERE DATA_TYPE NOT IN ('image','rowversion','timestamp','bit')
AND TABLE_SCHEMA LIKE @Table_Schema
AND TABLE_NAME LIKE @Table_Name
AND @Rerun = 1

UNION ALL

SELECT
'INSERT INTO ' + @OutputTable + ' SELECT ''' + COLUMN_NAME + ''' AS COLUMN_NAME' +
',''' + DATA_TYPE + ''' AS DATA_TYPE' +
',' + CAST(ORDINAL_POSITION AS NVARCHAR(4000)) + ' AS ORDINAL_POSITION' +
', CAST(MAX(CAST([' + COLUMN_NAME + '] AS INT)) AS NVARCHAR(500) ) AS MaxValue' +
', CAST(MIN(CAST([' + COLUMN_NAME + '] AS INT)) AS NVARCHAR(500) ) AS MinValue' +
', COUNT([' + COLUMN_NAME + ']) AS CountValue' +
', COUNT(DISTINCT [' + COLUMN_NAME + ']) AS DistinctCount' +
', COUNT( CASE WHEN [' + COLUMN_NAME + '] IS NULL THEN 1 ELSE NULL END) AS CountNulls' +
', (SELECT COUNT(1) + 1 FROM ' + @OutputTable + ' WHERE COLUMN_NAME = ''' + COLUMN_NAME + ''') AS dataProfileID' +
', SYSDATETIME() AS dataProfileDate' +
' FROM [' + TABLE_SCHEMA + '].[' + TABLE_NAME + '];'
FROM INFORMATION_SCHEMA.COLUMNS
WHERE DATA_TYPE ='bit'
AND TABLE_SCHEMA LIKE @Table_Schema
AND TABLE_NAME LIKE @Table_Name
AND @Rerun = 1

UNION ALL
SELECT '; SELECT *
FROM ' + @OutputTable + '
WHERE dataProfileID = (SELECT MAX(dataProfileID) FROM ' + @OutputTable + ')'

UNION ALL
SELECT COALESCE (
    'AND (
    COLUMN_NAME LIKE '''
    + STRING_AGG ( VALUE, '''
    OR COLUMN_NAME LIKE '''
    )
    + ''')'
,'')
FROM string_split(@ColumnListFilter, ',')

UNION ALL
SELECT
'
ORDER BY
ORDINAL_POSITION, /*or comment out this line to sort by simple data classification*/
SimpleDataClassification
;'
;

OPEN myCursor;
FETCH NEXT FROM myCursor INTO @SQL;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT @SQL;
    EXECUTE sp_executesql @SQL;
    FETCH NEXT FROM myCursor INTO @SQL;
END
CLOSE myCursor;
DEALLOCATE myCursor;
