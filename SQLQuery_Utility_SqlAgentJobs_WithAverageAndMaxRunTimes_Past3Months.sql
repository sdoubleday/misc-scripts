/* SD 2014-10-20
Gets a list of all of the SQL Agent jobs scheduled on a server.
NOTE! This will not include any jobs scheduled on a different server, but targeting this one.
It will also not include any jobs scheduled outside of SQL Server, such as backup jobs scheduled
through task manager for a SQL Express instance.

Combination of scripts from these two locations:

http://www.sqlservercentral.com/scripts/Maintenance+and+Management/62222/
http://www.mssqltips.com/sqlservertip/2850/querying-sql-server-agent-job-history-data/

*/


;WITH myRunHistory AS (
select 
 j.name as 'JobName',
 msdb.dbo.agent_datetime(run_date, run_time) as 'RunDateTime',
 ((run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 + 31 ) / 60) 
         as 'RunDurationMinutes'
From msdb.dbo.sysjobs j 
INNER JOIN msdb.dbo.sysjobhistory h 
 ON j.job_id = h.job_id 
where j.enabled = 1   --Only Enabled Jobs
--and j.name = 'TestJob' --Uncomment to search for a single job
/*
and msdb.dbo.agent_datetime(run_date, run_time) 
BETWEEN '12/08/2012' and '12/10/2012'  --Uncomment for date range queries
*/
)
, AggregateRunTimes AS (
SELECT 
JobName
, AVG(RunDurationMinutes) AS AverageRunDuration_InSlightlyRoundedMinutes_3Months
, MAX(RunDurationMinutes) AS MaxRunDuration_InSlightlyRoundedMinutes_3Months
, MAX(RunDateTime) AS MostRecentStartTime
FROM myRunHistory
WHERE RunDateTime > DATEADD(MONTH, -3, GETDATE())
GROUP BY JobName
)

-- Query to display schedules of jobs.  
--      copied from http://www.sqlservercentral.com/scripts/Maintenance+and+Management/62222/
--               posted there by "Cowboy DBA"
--    ----------
-- Revised 3/21/08 John Arnott
--   added default "ELSE" to case that would put plural "S" in schedule description.  (find comment " -- Added default 3/21/08; John Arnott"
-- Revised 6/19/08 John Arnott
--   re-coded the time parsing routines. Old code didn't handle first hour of the day (00:04, for instance).  
--   new code uses division by power of 10 to isolate hour, then minute portion of time,  
--   then a little trick with REPLICATE to left-fill the minutes with a zero if needed.
SELECT
   @@servername as [Server]
 , msdb.dbo.sysjobs.name as [JobName]
 , CASE
       WHEN msdb.dbo.sysjobs.enabled = 0 THEN 'Disabled'
       WHEN msdb.dbo.sysjobs.job_id IS NULL THEN 'Unscheduled'
       WHEN msdb.dbo.sysschedules.freq_type = 0x1 -- OneTime
           THEN
               'Once on '
             + CONVERT(
                          CHAR(10)
                        , CAST( CAST( msdb.dbo.sysschedules.active_start_date AS VARCHAR ) AS DATETIME )
                        , 102 -- yyyy.mm.dd
                       )
       WHEN msdb.dbo.sysschedules.freq_type = 0x4 -- Daily
           THEN 'Daily'
       WHEN msdb.dbo.sysschedules.freq_type = 0x8 -- weekly
           THEN
               CASE
                   WHEN msdb.dbo.sysschedules.freq_recurrence_factor = 1
                       THEN 'Weekly on '
                   WHEN msdb.dbo.sysschedules.freq_recurrence_factor > 1
                       THEN 'Every '
                          + CAST( msdb.dbo.sysschedules.freq_recurrence_factor AS VARCHAR )
                          + ' weeks on '
               END
             + LEFT(
                         CASE WHEN msdb.dbo.sysschedules.freq_interval &  1 =  1 THEN 'Sunday, '    ELSE '' END
                       + CASE WHEN msdb.dbo.sysschedules.freq_interval &  2 =  2 THEN 'Monday, '    ELSE '' END
                       + CASE WHEN msdb.dbo.sysschedules.freq_interval &  4 =  4 THEN 'Tuesday, '   ELSE '' END
                       + CASE WHEN msdb.dbo.sysschedules.freq_interval &  8 =  8 THEN 'Wednesday, ' ELSE '' END
                       + CASE WHEN msdb.dbo.sysschedules.freq_interval & 16 = 16 THEN 'Thursday, '  ELSE '' END
                       + CASE WHEN msdb.dbo.sysschedules.freq_interval & 32 = 32 THEN 'Friday, '    ELSE '' END
                       + CASE WHEN msdb.dbo.sysschedules.freq_interval & 64 = 64 THEN 'Saturday, '  ELSE '' END
                     , LEN(
                                CASE WHEN msdb.dbo.sysschedules.freq_interval &  1 =  1 THEN 'Sunday, '    ELSE '' END
                              + CASE WHEN msdb.dbo.sysschedules.freq_interval &  2 =  2 THEN 'Monday, '    ELSE '' END
                              + CASE WHEN msdb.dbo.sysschedules.freq_interval &  4 =  4 THEN 'Tuesday, '   ELSE '' END
                              + CASE WHEN msdb.dbo.sysschedules.freq_interval &  8 =  8 THEN 'Wednesday, ' ELSE '' END
                              + CASE WHEN msdb.dbo.sysschedules.freq_interval & 16 = 16 THEN 'Thursday, '  ELSE '' END
                              + CASE WHEN msdb.dbo.sysschedules.freq_interval & 32 = 32 THEN 'Friday, '    ELSE '' END
                              + CASE WHEN msdb.dbo.sysschedules.freq_interval & 64 = 64 THEN 'Saturday, '  ELSE '' END
                           )  - 1  -- LEN() ignores trailing spaces
                   )
       WHEN msdb.dbo.sysschedules.freq_type = 0x10 -- monthly
           THEN
               CASE
                   WHEN msdb.dbo.sysschedules.freq_recurrence_factor = 1
                       THEN 'Monthly on the '
                   WHEN msdb.dbo.sysschedules.freq_recurrence_factor > 1
                       THEN 'Every '
                          + CAST( msdb.dbo.sysschedules.freq_recurrence_factor AS VARCHAR )
                          + ' months on the '
               END
             + CAST( msdb.dbo.sysschedules.freq_interval AS VARCHAR )
             + CASE
                   WHEN msdb.dbo.sysschedules.freq_interval IN ( 1, 21, 31 ) THEN 'st'
                   WHEN msdb.dbo.sysschedules.freq_interval IN ( 2, 22     ) THEN 'nd'
                   WHEN msdb.dbo.sysschedules.freq_interval IN ( 3, 23     ) THEN 'rd'
                   ELSE 'th'
               END
       WHEN msdb.dbo.sysschedules.freq_type = 0x20 -- monthly relative
           THEN
               CASE
                   WHEN msdb.dbo.sysschedules.freq_recurrence_factor = 1
                       THEN 'Monthly on the '
                   WHEN msdb.dbo.sysschedules.freq_recurrence_factor > 1
                       THEN 'Every '
                          + CAST( msdb.dbo.sysschedules.freq_recurrence_factor AS VARCHAR )
                          + ' months on the '
               END
             + CASE msdb.dbo.sysschedules.freq_relative_interval
                   WHEN 0x01 THEN 'first '
                   WHEN 0x02 THEN 'second '
                   WHEN 0x04 THEN 'third '
                   WHEN 0x08 THEN 'fourth '
                   WHEN 0x10 THEN 'last '
               END
             + CASE msdb.dbo.sysschedules.freq_interval
                   WHEN  1 THEN 'Sunday'
                   WHEN  2 THEN 'Monday'
                   WHEN  3 THEN 'Tuesday'
                   WHEN  4 THEN 'Wednesday'
                   WHEN  5 THEN 'Thursday'
                   WHEN  6 THEN 'Friday'
                   WHEN  7 THEN 'Saturday'
                   WHEN  8 THEN 'day'
                   WHEN  9 THEN 'week day'
                   WHEN 10 THEN 'weekend day'
               END
       WHEN msdb.dbo.sysschedules.freq_type = 0x40
           THEN 'Automatically starts when SQLServerAgent starts.'
       WHEN msdb.dbo.sysschedules.freq_type = 0x80
           THEN 'Starts whenever the CPUs become idle'
       ELSE ''
   END
 + CASE
       WHEN msdb.dbo.sysjobs.enabled = 0 THEN ''
       WHEN msdb.dbo.sysjobs.job_id IS NULL THEN ''
       WHEN msdb.dbo.sysschedules.freq_subday_type = 0x1 OR msdb.dbo.sysschedules.freq_type = 0x1
           THEN ' at '
                        + Case  -- Depends on time being integer to drop right-side digits
                                when(msdb.dbo.sysschedules.active_start_time % 1000000)/10000 = 0 then 
                                                  '12'
                                                + ':'  
                                                +Replicate('0',2 - len(convert(char(2),(msdb.dbo.sysschedules.active_start_time % 10000)/100)))
                                                + convert(char(2),(msdb.dbo.sysschedules.active_start_time % 10000)/100) 
                                                + ' AM'
                                when (msdb.dbo.sysschedules.active_start_time % 1000000)/10000< 10 then
                                                convert(char(1),(msdb.dbo.sysschedules.active_start_time % 1000000)/10000) 
                                                + ':'  
                                                +Replicate('0',2 - len(convert(char(2),(msdb.dbo.sysschedules.active_start_time % 10000)/100))) 
                                                + convert(char(2),(msdb.dbo.sysschedules.active_start_time % 10000)/100) 
                                                + ' AM'
                                when (msdb.dbo.sysschedules.active_start_time % 1000000)/10000 < 12 then
                                                convert(char(2),(msdb.dbo.sysschedules.active_start_time % 1000000)/10000) 
                                                + ':'  
                                                +Replicate('0',2 - len(convert(char(2),(msdb.dbo.sysschedules.active_start_time % 10000)/100))) 
                                                + convert(char(2),(msdb.dbo.sysschedules.active_start_time % 10000)/100) 
                                                + ' AM'
                                when (msdb.dbo.sysschedules.active_start_time % 1000000)/10000< 22 then
                                                convert(char(1),((msdb.dbo.sysschedules.active_start_time % 1000000)/10000) - 12) 
                                                + ':'  
                                                +Replicate('0',2 - len(convert(char(2),(msdb.dbo.sysschedules.active_start_time % 10000)/100))) 
                                                + convert(char(2),(msdb.dbo.sysschedules.active_start_time % 10000)/100) 
                                                + ' PM'
                                else        convert(char(2),((msdb.dbo.sysschedules.active_start_time % 1000000)/10000) - 12)
                                                + ':'  
                                                +Replicate('0',2 - len(convert(char(2),(msdb.dbo.sysschedules.active_start_time % 10000)/100))) 
                                                + convert(char(2),(msdb.dbo.sysschedules.active_start_time % 10000)/100) 
                                                + ' PM'
                        end
       WHEN msdb.dbo.sysschedules.freq_subday_type IN ( 0x2, 0x4, 0x8 )
           THEN ' every '
             + CAST( msdb.dbo.sysschedules.freq_subday_interval AS VARCHAR )
             + CASE freq_subday_type
                   WHEN 0x2 THEN ' second'
                   WHEN 0x4 THEN ' minute'
                   WHEN 0x8 THEN ' hour'
               END
             + CASE
                   WHEN msdb.dbo.sysschedules.freq_subday_interval > 1 THEN 's'
                                   ELSE '' -- Added default 3/21/08; John Arnott
               END
       ELSE ''
   END
 + CASE
       WHEN msdb.dbo.sysjobs.enabled = 0 THEN ''
       WHEN msdb.dbo.sysjobs.job_id IS NULL THEN ''
       WHEN msdb.dbo.sysschedules.freq_subday_type IN ( 0x2, 0x4, 0x8 )
           THEN ' between '
                        + Case  -- Depends on time being integer to drop right-side digits
                                when(msdb.dbo.sysschedules.active_start_time % 1000000)/10000 = 0 then 
                                                  '12'
                                                + ':'  
                                                +Replicate('0',2 - len(convert(char(2),(msdb.dbo.sysschedules.active_start_time % 10000)/100)))
                                                + rtrim(convert(char(2),(msdb.dbo.sysschedules.active_start_time % 10000)/100))
                                                + ' AM'
                                when (msdb.dbo.sysschedules.active_start_time % 1000000)/10000< 10 then
                                                convert(char(1),(msdb.dbo.sysschedules.active_start_time % 1000000)/10000) 
                                                + ':'  
                                                +Replicate('0',2 - len(convert(char(2),(msdb.dbo.sysschedules.active_start_time % 10000)/100))) 
                                                + rtrim(convert(char(2),(msdb.dbo.sysschedules.active_start_time % 10000)/100))
                                                + ' AM'
                                when (msdb.dbo.sysschedules.active_start_time % 1000000)/10000 < 12 then
                                                convert(char(2),(msdb.dbo.sysschedules.active_start_time % 1000000)/10000) 
                                                + ':'  
                                                +Replicate('0',2 - len(convert(char(2),(msdb.dbo.sysschedules.active_start_time % 10000)/100))) 
                                                + rtrim(convert(char(2),(msdb.dbo.sysschedules.active_start_time % 10000)/100)) 
                                                + ' AM'
                                when (msdb.dbo.sysschedules.active_start_time % 1000000)/10000< 22 then
                                                convert(char(1),((msdb.dbo.sysschedules.active_start_time % 1000000)/10000) - 12) 
                                                + ':'  
                                                +Replicate('0',2 - len(convert(char(2),(msdb.dbo.sysschedules.active_start_time % 10000)/100))) 
                                                + rtrim(convert(char(2),(msdb.dbo.sysschedules.active_start_time % 10000)/100)) 
                                                + ' PM'
                                else        convert(char(2),((msdb.dbo.sysschedules.active_start_time % 1000000)/10000) - 12)
                                                + ':'  
                                                +Replicate('0',2 - len(convert(char(2),(msdb.dbo.sysschedules.active_start_time % 10000)/100))) 
                                                + rtrim(convert(char(2),(msdb.dbo.sysschedules.active_start_time % 10000)/100))
                                                + ' PM'
                        end
             + ' and '
                        + Case  -- Depends on time being integer to drop right-side digits
                                when(msdb.dbo.sysschedules.active_end_time % 1000000)/10000 = 0 then 
                                                '12'
                                                + ':'  
                                                +Replicate('0',2 - len(convert(char(2),(msdb.dbo.sysschedules.active_end_time % 10000)/100)))
                                                + rtrim(convert(char(2),(msdb.dbo.sysschedules.active_end_time % 10000)/100))
                                                + ' AM'
                                when (msdb.dbo.sysschedules.active_end_time % 1000000)/10000< 10 then
                                                convert(char(1),(msdb.dbo.sysschedules.active_end_time % 1000000)/10000) 
                                                + ':'  
                                                +Replicate('0',2 - len(convert(char(2),(msdb.dbo.sysschedules.active_end_time % 10000)/100))) 
                                                + rtrim(convert(char(2),(msdb.dbo.sysschedules.active_end_time % 10000)/100))
                                                + ' AM'
                                when (msdb.dbo.sysschedules.active_end_time % 1000000)/10000 < 12 then
                                                convert(char(2),(msdb.dbo.sysschedules.active_end_time % 1000000)/10000) 
                                                + ':'  
                                                +Replicate('0',2 - len(convert(char(2),(msdb.dbo.sysschedules.active_end_time % 10000)/100))) 
                                                + rtrim(convert(char(2),(msdb.dbo.sysschedules.active_end_time % 10000)/100))
                                                + ' AM'
                                when (msdb.dbo.sysschedules.active_end_time % 1000000)/10000< 22 then
                                                convert(char(1),((msdb.dbo.sysschedules.active_end_time % 1000000)/10000) - 12)
                                                + ':'  
                                                +Replicate('0',2 - len(convert(char(2),(msdb.dbo.sysschedules.active_end_time % 10000)/100))) 
                                                + rtrim(convert(char(2),(msdb.dbo.sysschedules.active_end_time % 10000)/100)) 
                                                + ' PM'
                                else        convert(char(2),((msdb.dbo.sysschedules.active_end_time % 1000000)/10000) - 12)
                                                + ':'  
                                                +Replicate('0',2 - len(convert(char(2),(msdb.dbo.sysschedules.active_end_time % 10000)/100))) 
                                                + rtrim(convert(char(2),(msdb.dbo.sysschedules.active_end_time % 10000)/100)) 
                                                + ' PM'
                        end
       ELSE ''
   END AS Schedule,
CASE
       WHEN msdb.dbo.sysschedules.enabled = 0 THEN 'Disabled'
	   WHEN msdb.dbo.sysschedules.enabled = 1 THEN 'Enabled'
	END
  As [Schedule Enabled]

--,AggregateRunTimes.MostRecentStartTime
,CAST(AggregateRunTimes.MostRecentStartTime AS TIME) AS MostRecentStartTime_AsTime
,AggregateRunTimes.AverageRunDuration_InSlightlyRoundedMinutes_3Months
,AggregateRunTimes.MaxRunDuration_InSlightlyRoundedMinutes_3Months
FROM         msdb.dbo.sysjobs INNER JOIN
                      msdb.dbo.sysjobschedules ON msdb.dbo.sysjobs.job_id = msdb.dbo.sysjobschedules.job_id INNER JOIN
                      msdb.dbo.sysschedules ON msdb.dbo.sysjobschedules.schedule_id = msdb.dbo.sysschedules.schedule_id
LEFT OUTER JOIN AggregateRunTimes
ON sysjobs.name = AggregateRunTimes.JobName

--where msdb.dbo.sysjobs.name like '%DCT%'
order by MostRecentStartTime_ASTime, 2


