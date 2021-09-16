SELECT 'SELECT * INTO #DataProfile FROM ( '
UNION ALL
SELECT
'SELECT [''' + COLUMN_NAME + '''] AS COLUMN_NAME' +
', CAST(MAX([' + COLUMN_NAME + ']) AS NVARCHAR(500) ) AS MaxValue' +
', CAST(MIN([' + COLUMN_NAME + ']) AS NVARCHAR(500) ) AS MinValue' +
', COUNT([' + COLUMN_NAME + ']) AS CountValue' +
', COUNT(DISTINCT [' + COLUMN_NAME + ']) AS DistinctCount' +
', SUM( CASE WHEN [' + COLUMN_NAME + '] IS NULL THEN 1 ELSE 0 END) AS CountNulls' +
' FROM [' + TABLE_SCHEMA + '].[' + TABLE_NAME + '] UNION ALL'
FROM INFORMATION_SCHEMA.COLUMNS
WHERE DATA_TYPE NOT IN ('image','rowversion','timestamp')
AND TABLE_SCHEMA LIKE '%%'
AND TABLE_NAME LIKE '%ReplaceMe%'

UNION ALL
SELECT ') AS a; SELECT * FROM #DataProfile;'

/*Copy the output, Take out the trailing UNION ALL, and run it.*/
;
