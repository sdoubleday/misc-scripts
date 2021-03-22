/*Look up more documentation of that unofficial stored procedure before relying on this. It only looks at
certain error files*/

IF OBJECT_ID('tempDB..#errors') IS NOT NULL 
DROP TABLE #errors

create table #errors (id INT IDENTITY (1,1), LogDate DATETIME, ProcessInfo varchar(50), text varchar(max))


INSERT INTO #errors  EXEC sp_readerrorlog

;WITH myErrors AS (
SELECT * , 'Error' AS myFlag FROM #errors 
where 
text like 'Error%'
UNION ALL
SELECT * , 'Use Of SA' AS myFlag FROM #errors 
where 
text like '%''sa''%'
)
SELECT * FROM #errors e
INNER JOIN
(
	SELECT id , myflag FROM myErrors
	UNION
	SELECT id + 1 AS id , myflag from myErrors WHERE myFlag LIKE 'Error'
) AS myfilter on e.id = myfilter.id

ORDER BY myFlag DESC
,logDate