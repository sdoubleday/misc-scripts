/*
From:
http://dba.stackexchange.com/questions/30112/does-sql-server-2008-store-the-creation-date-of-execution-plans

They have recompile hints for each of the two queries, and I am not sure if that is necessary or not.
*/

;with myPlanCacheData AS (
	SELECT 
		p.name AS [SP Name]
		, ps.execution_count
		, ps.cached_time
		, 'Procedure Plan' AS ProcOrAdHoc
	FROM 
		sys.procedures p WITH (NOLOCK)
	INNER JOIN 
		sys.dm_exec_procedure_stats ps WITH (NOLOCK)
	ON  p.[object_id] = ps.[object_id]
	WHERE 
		ps.database_id = DB_ID()
	    
	UNION ALL

	SELECT 
		st.[text] AS [QueryText]
		, qs.execution_count
		, qs.creation_time AS cached_time
		, 'Ad Hoc Plan' AS ProcOrAdHoc
	FROM 
		sys.dm_exec_cached_plans cp WITH (NOLOCK)
	INNER JOIN
		sys.dm_exec_query_stats qs WITH (NOLOCK)
	ON  qs.plan_handle = cp.plan_handle
	CROSS APPLY 
		sys.dm_exec_sql_text(cp.plan_handle) st
	WHERE 
		cp.objtype = N'Adhoc' 
)
SELECT * 
FROM myPlanCacheData 
ORDER BY 
ProcOrAdHoc DESC
,cached_time DESC