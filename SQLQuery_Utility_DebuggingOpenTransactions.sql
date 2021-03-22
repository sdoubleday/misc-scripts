
IF OBJECT_ID('tempdb..#OpenTranStatus') IS NOT NULL
DROP table #OpenTranStatus 
-- Create the temporary table to accept the results.
CREATE TABLE #OpenTranStatus (
   ActiveTransaction varchar(25),
   Details NVARCHAR(4000)
   );
-- Execute the command, putting the results in the table.
INSERT INTO #OpenTranStatus 
   EXEC ('DBCC OPENTRAN WITH TABLERESULTS, NO_INFOMSGS');

-- Display the results.
SELECT * FROM #OpenTranStatus;
GO

SELECT *
FROM sys.dm_exec_sessions
WHERE session_id = (SELECt TOP 1details from #OpenTranStatus where ActiveTransaction like '%SPID%')