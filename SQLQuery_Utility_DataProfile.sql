DECLARE @Table_Name NVARCHAR(128) = N'ReplaceMe';
DECLARE @Table_Schema NVARCHAR(128) = N'dbo';

DECLARE @DecimalCutoffForLowCardinality_DistinctOverCount NVARCHAR(128) = N'0.0001';
DECLARE @DecimalCutoffForMediumCardinality_DistinctOverCount NVARCHAR(128) = N'0.001';

DECLARE @TempTable NVARCHAR(128) = N'#DataProfile_' + @Table_Schema + N'_' + @Table_Name;

DECLARE @SQL NVARCHAR(4000) = '';
DECLARE myCursor CURSOR FOR
SELECT 
'CREATE TABLE ' + @TempTable + '
(
     COLUMN_NAME SYSNAME NOT NULL
    ,DATA_TYPE SYSNAME NOT NULL
    ,ORDINAL_POSITION INT NOT NULL
    ,MaxValue NVARCHAR(500) NULL
    ,MaxValue NVARCHAR(500) NULL
    ,MinValue NVARCHAR(500) NULL
    ,CountValue BIGINT NOT NULL
    ,DistinctCount BIGINT NOT NULL
    ,CountNulls BIGINT NOT NULL
);'

UNION ALL

SELECT
'INSERT INTO ' + @TempTable + ' SELECT ''' + COLUMN_NAME + ''' AS COLUMN_NAME' +
',''' + DATA_TYPE + ''' AS DATA_TYPE' +
',' + ORDINAL_POSITION + ' AS ORDINAL_POSITION' +
', CAST(MAX([' + COLUMN_NAME + ']) AS NVARCHAR(500) ) AS MaxValue' +
', CAST(MIN([' + COLUMN_NAME + ']) AS NVARCHAR(500) ) AS MinValue' +
', COUNT([' + COLUMN_NAME + ']) AS CountValue' +
', COUNT(DISTINCT [' + COLUMN_NAME + ']) AS DistinctCount' +
', SUM( CASE WHEN [' + COLUMN_NAME + '] IS NULL THEN 1 ELSE 0 END) AS CountNulls' +
' FROM [' + TABLE_SCHEMA + '].[' + TABLE_NAME + '];'
FROM INFORMATION_SCHEMA.COLUMNS
WHERE DATA_TYPE NOT IN ('image','rowversion','timestamp','bit')
AND TABLE_SCHEMA LIKE @Table_Schema
AND TABLE_NAME LIKE @Table_Name

UNION ALL

SELECT
'INSERT INTO ' + @TempTable + ' SELECT ''' + COLUMN_NAME + ''' AS COLUMN_NAME' +
',''' + DATA_TYPE + ''' AS DATA_TYPE' +
',' + ORDINAL_POSITION + ' AS ORDINAL_POSITION' +
', CAST(MAX(CAST([' + COLUMN_NAME + '] AS INT)) AS NVARCHAR(500) ) AS MaxValue' +
', CAST(MIN(CAST([' + COLUMN_NAME + '] AS INT)) AS NVARCHAR(500) ) AS MinValue' +
', COUNT([' + COLUMN_NAME + ']) AS CountValue' +
', COUNT(DISTINCT [' + COLUMN_NAME + ']) AS DistinctCount' +
', SUM( CASE WHEN [' + COLUMN_NAME + '] IS NULL THEN 1 ELSE 0 END) AS CountNulls' +
' FROM [' + TABLE_SCHEMA + '].[' + TABLE_NAME + '];'
FROM INFORMATION_SCHEMA.COLUMNS
WHERE DATA_TYPE ='bit'
AND TABLE_SCHEMA LIKE @Table_Schema
AND TABLE_NAME LIKE @Table_Name

UNION ALL
SELECT '; SELECT *
, CASE WHEN DistinctCount = 2 THEN ''Binary-Y/N-True/False''
    WHEN DistinctCount = 1 AND CountNulls > 0 THEN ''Unary With Nulls''
    WHEN CAST(DistinctCount AS DECIMAL(19,10)) / CountValue < ' + @DecimalCutoffForLowCardinality_DistinctOverCount + ' THEN ''Low Cardinality''
    WHEN CAST(DistinctCount AS DECIMAL(19,10)) / CountValue < ' + @DecimalCutoffForMediumCardinality_DistinctOverCount + ' THEN ''Medium Cardinality''
    WHEN DistinctCount = CountValue AND CountNulls = 0 THEN ''Unique Per Row''
    WHEN DATA_TYPE = ''UNIQUEIDENTIFIER'' THEN ''DATA_TYPE UNIQUEIDENTIFIER''
    WHEN DATA_TYPE LIKE ''DATE'' THEN ''DATA_TYPE Date''
    WHEN DATA_TYPE LIKE ''TIME'' THEN ''DATA_TYPE Time''
    WHEN DATA_TYPE LIKE ''%DATE%''  THEN ''DATA_TYPE DateTime''
END AS SimpleDataClassification
FROM ' + @TempTable + '
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
