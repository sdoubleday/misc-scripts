/*In general, ust running SP_WHO is going to be what you need. But if you are scripting...*/
IF OBJECT_ID ('tempdb..#myWho') IS NOT NULL
DROP TABLE #myWho
Create  Table #myWho (spid INT, ecid INT, [status] Nvarchar(128), loginame sysname, hostname nvarchar(250), blk int, dbname NVARCHAR(128), cmd nvarchar(100), request_id int)

INSERT into #myWho
EXEC sp_who 

SELECT DISTINCT SUBSTRING(hostname,0,CHARIndex(' ',hostname)) AS Servername from #myWho where NULLIF(hostname ,'') IS NOT NULL
