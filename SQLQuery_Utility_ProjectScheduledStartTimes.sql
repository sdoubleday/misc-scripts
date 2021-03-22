
USE msdb
GO
IF OBJECT_ID('dbo.usp_GetJobScheduleData') IS NOT NULL
BEGIN
	DROP PROCEDURE dbo.usp_GetJobScheduleData
END
GO
CREATE PROCEDURE dbo.usp_GetJobScheduleData
@StartDateTime_Inc	DATETIME = '2015-05-01'
,@EndDateTime_Excl	DATETIME = '2015-05-15'

AS 
SET FMTONLY OFF
/*This only works for jobs that have actually RUN and it ignores jobs set to run when CPU is idle
and on startup.*/
/*
Note: before I publish this, I should swap the date params back in
I've got a lot of code between here and where I'm using these dates, so I'm stashing them in a Temp table.*/


IF OBJECT_ID('tempdb..#JobDurations') IS NOT NULL
BEGIN
	DROP Table #JobDurations;
END
IF OBJECT_ID('tempdb..#dateParams') IS NOT NULL
BEGIN
	DROP Table #dateParams;
END
SELECT @StartDateTime_Inc AS StartDateTime_Inc
,@EndDateTime_Excl AS EndDateTime_Excl
INTO #dateParams

/*Because we cannot assume a tally table, we make one.*/
IF OBJECT_ID('tempdb..#Tally') IS NOT NULL
BEGIN
	DROP Table #Tally;
END
IF OBJECT_ID('tempdb..#DimDate') IS NOT NULL
BEGIN
	DROP Table #DimDate;
END
/*Make Tally, starting from 0. There are 86400 seconds per day, which is also plenty of days.*/
SELECT TOP 86400 N=IDENTITY(Int,0,1)
INTO #Tally
FROM master.sys.syscolumns a CROSS JOIN master.sys.syscolumns b;
ALTER TABLE #Tally ADD HHMMSS AS RIGHT('0' + CAST(N/3600 AS VARCHAR),2) + 
	+ RIGHT('0' + CAST((N / 60) % 60 AS VARCHAR),2) + 
	+ RIGHT('0' + CAST(N  % 60 AS VARCHAR),2) PERSISTED
ALTER TABLE #Tally ADD CONSTRAINT NBR_pk PRIMARY KEY (N);
CREATE INDEX tallyHHMMSS ON #Tally (HHMMSS) INCLUDE (N);

/*Make dimDate, tailored to our needs.
*/
/*Treat Sunday as the first day of the week. This is the default.*/
SET DATEFIRST 7

;WITH myDates AS (
SELECT DATEADD(DAY, N - 1, StartDate) AS FullDate
,CalendarMonth_FirstMonthOfFiscalYear 
,GETDATE() AS Today
from #Tally
Cross apply (
	SELECT CAST(StartDate AS DATETIME) AS StartDate,
	CalendarMonth_FirstMonthOfFiscalYear
	FROM (VALUES
		('1900-01-01',7)
	) A (StartDate,
	CalendarMonth_FirstMonthOfFiscalYear
	)
) AS MakeDates
Where N <= 2958463 /*Max date for a datetime datatype. We didn't make this many rows, but just to be certain.*/
AND N >= 1
)

,dimDate AS (
SELECT
		 FullDate
	   , CONVERT(INT, CONVERT(VARCHAR(8), FullDate, 112)) AS DateKey
	   , DayNumberOfWeek
	   , IsWeekDay
	   , IsWeekend
	   , IsLastDayOfWeek
	   , RANK() OVER (PARTITION BY CalendarYear, MonthNumberOfYear, IsWeekDay ORDER BY FullDate) AS NumberedWeekDaysAndWeekendDays
	   , CASE WHEN RANK() OVER (PARTITION BY CalendarYear, MonthNumberOfYear, IsWeekDay ORDER BY FullDate DESC) = 1 THEN 1 ELSE 0
			END AS IsLastWeekDayOrWeekendDay
       , RANK() OVER (PARTITION BY CalendarYear, MonthNumberOfYear, DayNumberOfWeek ORDER BY FullDate) AS NumberedInstancesOfDayOfWeekWithinMonth
       , CASE WHEN RANK() OVER (PARTITION BY CalendarYear, MonthNumberOfYear, DayNumberOfWeek ORDER BY FullDate DESC) = 1 THEN 1 ELSE 0
			END AS IsLastInstanceOfDayOfWeekWithinMonth
       , DAY(FullDate) AS DayNumberOfMonth
       , IsLastDayOfMonth
       , WeekNumberOfMonth
	   , IsLastWeekOfMonth
       , MonthNumberOfYear
       
       
FROM myDates
CROSS APPLY (
	SELECT 
	DATEADD(DAY, 1, FULLDATE) AS PlusOneDay
	,DATEADD(WEEK, 1, FULLDATE) AS PlusOneWeek
)FakeLead
CROSS APPLY (
SELECT
/*
To be honest, I have no idea how this Week Number code works, but the result is to count the first partial week as week one.
I got it from here:
http://stackoverflow.com/questions/13116222/how-to-get-week-number-of-the-month-from-the-date-in-sql-server-2008
*/
 datediff(week, dateadd(week, datediff(week, 0, dateadd(month, datediff(month, 0, FullDate), 0)), 0), Fulldate - 1) + 1 AS WeekNumberOfMonth
,CASE WHEN MONTH(FullDate) <> MONTH(PlusOneDay) THEN 1 ELSE 0 END AS IsLastDayOfMonth
/*Add a day - same week? If not, last day.*/
,CASE WHEN DATEPART(wk, FullDate) <> DATEPART(wk, PlusOneDay) THEN 1 ELSE 0 END AS IsLastDayOfWeek
/*Add a week - same month? If not, last week.*/
,CASE WHEN datediff(week, dateadd(week, datediff(week, 0, dateadd(month, datediff(month, 0, FullDate), 0)), 0), Fulldate - 1) + 1 
	<> datediff(week, dateadd(week, datediff(week, 0, dateadd(month, datediff(month, 0, PlusOneWeek), 0)), 0), PlusOneWeek - 1) + 1 
	THEN 1
	ELSE 0
END AS IsLastWeekOfMonth

,DATEPART(dw, FullDate) AS DayNumberOfWeek
,CASE WHEN DATEPART(dw, FullDate) = 1
	OR DATEPART(dw, FullDate) = 7
	THEN 1
	ELSE 0
END AS IsWeekend
,CASE WHEN DATEPART(dw, FullDate) = 2
	OR DATEPART(dw, FullDate) = 3
	OR DATEPART(dw, FullDate) = 4
	OR DATEPART(dw, FullDate) = 5
	OR DATEPART(dw, FullDate) = 6
	THEN 1
	ELSE 0
END AS IsWeekDay
,YEAR(FullDate) AS CalendarYear
,MONTH(FullDate) AS MonthNumberOfYear

) AS GenerateUsefulStuff

)/*end DimDate*/

SELECT *
INTO #dimDate
FROM dimDate
ALTER TABLE #dimDate ALTER COLUMN FullDate DATETIME NOT NULL;
ALTER TABLE #dimDate ALTER COLUMN DATEKEY INT NOT NULL;
ALTER TABLE #dimDate ADD CONSTRAINT date_pk PRIMARY KEY (DateKey, FullDate);

--select top 5 * FROM #dimdate order by datekey
--SELECT TOP 5 * from #Tally
--SELECT TOP 5 * from #Tally ORDER BY n DESC


/*
ENABLED AND SCHEDULED ONLY!



Taken directly from here
http://www.sqlprofessionals.com/blog/sql-scripts/2014/10/06/insight-into-sql-agent-job-schedules/

sdoubleday 2015-09-15
Modified to calculate minutes of run time and to only list Enabled, Scheduled jobs.
*/
SELECT   
 [JobName]			= [jobs].[name]
,[Category]			= [categories].[name]
,[Owner]			= SUSER_SNAME([jobs].[owner_sid])
,[Enabled]			= CASE [jobs].[enabled] WHEN 1 THEN 'Yes' ELSE 'No' END
,[Scheduled]		= CASE [schedule].[enabled] WHEN 1 THEN 'Yes' ELSE 'No' END
,[Description]		= [jobs].[description]
,[Occurs]			=
					CASE [schedule].[freq_type]
					WHEN   1 THEN 'Once'
					WHEN   4 THEN 'Daily'
					WHEN   8 THEN 'Weekly'
					WHEN  16 THEN 'Monthly'
					WHEN  32 THEN 'Monthly relative'
					WHEN  64 THEN 'When SQL Server Agent starts'
					WHEN 128 THEN 'Start whenever the CPU(s) become idle'
					ELSE ''
					END
,[Occurs_detail]	=
					CASE [schedule].[freq_type]
					WHEN   1 THEN 'Once'
					WHEN   4 THEN 'Every ' + CONVERT(VARCHAR, [schedule].[freq_interval]) + ' day(s)'
					WHEN   8 THEN 'Every ' + CONVERT(VARCHAR, [schedule].[freq_recurrence_factor]) + ' weeks(s) on ' +
					LEFT
					(
					/*
					sdoubleday Notes
					This use of the ampersand is a bitwise operator. I have no idea what that bit of magic is,
					but it works. Yay!*/
					CASE WHEN [schedule].[freq_interval] &  1 =  1 THEN 'Sunday, '    ELSE '' END +
					CASE WHEN [schedule].[freq_interval] &  2 =  2 THEN 'Monday, '    ELSE '' END +
					CASE WHEN [schedule].[freq_interval] &  4 =  4 THEN 'Tuesday, '   ELSE '' END +
					CASE WHEN [schedule].[freq_interval] &  8 =  8 THEN 'Wednesday, ' ELSE '' END +
					CASE WHEN [schedule].[freq_interval] & 16 = 16 THEN 'Thursday, '  ELSE '' END +
					CASE WHEN [schedule].[freq_interval] & 32 = 32 THEN 'Friday, '    ELSE '' END +
					CASE WHEN [schedule].[freq_interval] & 64 = 64 THEN 'Saturday, '  ELSE '' END ,
					LEN
					(
					CASE WHEN [schedule].[freq_interval] &  1 =  1 THEN 'Sunday, '    ELSE '' END +
					CASE WHEN [schedule].[freq_interval] &  2 =  2 THEN 'Monday, '    ELSE '' END +
					CASE WHEN [schedule].[freq_interval] &  4 =  4 THEN 'Tuesday, '   ELSE '' END +
					CASE WHEN [schedule].[freq_interval] &  8 =  8 THEN 'Wednesday, ' ELSE '' END +
					CASE WHEN [schedule].[freq_interval] & 16 = 16 THEN 'Thursday, '  ELSE '' END +
					CASE WHEN [schedule].[freq_interval] & 32 = 32 THEN 'Friday, '    ELSE '' END +
					CASE WHEN [schedule].[freq_interval] & 64 = 64 THEN 'Saturday, '  ELSE '' END
					) - 1
					)
					WHEN  16 THEN 'Day ' + CONVERT(VARCHAR, [schedule].[freq_interval]) + ' of every ' + CONVERT(VARCHAR, [schedule].[freq_recurrence_factor]) + ' month(s)'
					WHEN  32 THEN 'The ' +
					CASE [schedule].[freq_relative_interval]
					WHEN  1 THEN 'First'
					WHEN  2 THEN 'Second'
					WHEN  4 THEN 'Third'
					WHEN  8 THEN 'Fourth'
					WHEN 16 THEN 'Last'
					END +
					CASE [schedule].[freq_interval]
					WHEN  1 THEN ' Sunday'
					WHEN  2 THEN ' Monday'
					WHEN  3 THEN ' Tuesday'
					WHEN  4 THEN ' Wednesday'
					WHEN  5 THEN ' Thursday'
					WHEN  6 THEN ' Friday'
					WHEN  7 THEN ' Saturday'
					WHEN  8 THEN ' Day'
					WHEN  9 THEN ' Weekday'
					WHEN 10 THEN ' Weekend Day'
					END + ' of every ' + CONVERT(VARCHAR, [schedule].[freq_recurrence_factor]) + ' month(s)'
					ELSE ''
					END
,[Frequency]		=
					CASE [schedule].[freq_subday_type]
					WHEN 1 THEN 'Occurs once at ' +
					STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), [schedule].[active_start_time]), 6), 5, 0, ':'), 3, 0, ':')
					WHEN 2 THEN 'Occurs every ' +
					CONVERT(VARCHAR, [schedule].[freq_subday_interval]) + ' Seconds(s) between ' +
					STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), [schedule].[active_start_time]), 6), 5, 0, ':'), 3, 0, ':') + ' and ' +
					STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), [schedule].[active_end_time]), 6), 5, 0, ':'), 3, 0, ':')
					WHEN 4 THEN 'Occurs every ' +
					CONVERT(VARCHAR, [schedule].[freq_subday_interval]) + ' Minute(s) between ' +
					STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), [schedule].[active_start_time]), 6), 5, 0, ':'), 3, 0, ':') + ' and ' +
					STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), [schedule].[active_end_time]), 6), 5, 0, ':'), 3, 0, ':')
					WHEN 8 THEN 'Occurs every ' +
					CONVERT(VARCHAR, [schedule].[freq_subday_interval]) + ' Hour(s) between ' +
					STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), [schedule].[active_start_time]), 6), 5, 0, ':'), 3, 0, ':') + ' and ' +
					STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), [schedule].[active_end_time]), 6), 5, 0, ':'), 3, 0, ':')
					ELSE ''
					END
,[AvgDurationInSec] = CONVERT(DECIMAL(10, 2), [jobhistory].[AvgDuration])
,[AvgDurationInMin] = CONVERT(DECIMAL(10, 2), [jobhistory].[AvgDuration]) / 60.0
,[Duration_MeanPlus2StdDv_RoundedToSecs] = CAST([jobhistory].[AvgDuration] + 2 * [jobhistory].StandardDevPop AS INT)
,[Next_Run_Date]	=
						CASE [jobschedule].[next_run_date]
						WHEN 0 THEN CONVERT(DATETIME, '1900/1/1')
						ELSE CONVERT(DATETIME, CONVERT(CHAR(8), [jobschedule].[next_run_date], 112) + ' ' +
						STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), [jobschedule].[next_run_time]), 6), 5, 0, ':'), 3, 0, ':'))
						END
,[ServerName]		= @@SERVERNAME  
,[schedule_id]		= [schedule].schedule_id
INTO #JobDurations
FROM	[msdb].[dbo].[sysjobs] AS [jobs] WITH (NOLOCK)
LEFT OUTER JOIN [msdb].[dbo].[sysjobschedules] AS [jobschedule] WITh(NOLOCK)
ON [jobs].[job_id] = [jobschedule].[job_id]
LEFT OUTER JOIN [msdb].[dbo].[sysschedules] AS [schedule] WITh(NOLOCK)
ON [jobschedule].[schedule_id] = [schedule].[schedule_id]
INNER JOIN [msdb].[dbo].[syscategories] [categories] WITh(NOLOCK)
ON [jobs].[category_id] = [categories].[category_id]
LEFT OUTER JOIN
(	
SELECT	  [job_id]
, [AvgDuration] = AVG(
		(
			(
				([run_duration] / 10000 * 3600) + (([run_duration] % 10000) / 100 * 60) + ([run_duration] % 10000) % 100
			)
		) * 1.0
	)
, [StandardDevPop] = STDEVP(
		(
			(
				([run_duration] / 10000 * 3600) + (([run_duration] % 10000) / 100 * 60) + ([run_duration] % 10000) % 100
			)
		) * 1.0
	)

FROM	  [msdb].[dbo].[sysjobhistory] WITh(NOLOCK)
WHERE	  [step_id] = 0
GROUP BY [job_id]
  ) AS [jobhistory]
ON [jobhistory].[job_id] = [jobs].[job_id]
WHERE [jobs].[enabled] = 1
AND  [schedule].[enabled] = 1



;WITH mySchedulesProjected AS (
SELECT [sysschedules].*
,d.*
,t.*
FROM [msdb].[dbo].[sysschedules]
CROSS JOIN #dateParams dp
INNER JOIN #dimDate d
ON d.FullDate >= dp.StartDateTime_Inc
AND d.FullDate < dp.EndDateTime_Excl
/*Only pick dates that meet the schedule frequency type and related interval and relative settings.
Cases output 0 for false and 1 for true.*/
AND CASE [sysschedules].freq_type
	WHEN 0x1 THEN 
		CASE WHEN sysschedules.active_start_date = d.DateKey THEN 1 ELSE 0 END /*Run Once - Pick one day*/
	WHEN 0x4 THEN /*Daily - Pick all the days where modulo from start date by the frequency interval equals zero.*/
		CASE WHEN DATEDIFF(Day, CONVERT(DATE,CAST(sysschedules.active_start_date AS CHAR(8)), 112), d.FullDate) % sysschedules.freq_interval = 0 THEN 1 ELSE 0 END
	WHEN 0x8 THEN /*Weekly - only certain days, based on a power of two thingy*/
		CASE WHEN /*I don't understand bitwise math, I just use recipes that have it in them.*/
			sysschedules.freq_interval & POWER(2, d.DayNumberOfWeek - 1 ) = POWER(2, d.DayNumberOfWeek - 1 )
			THEN 1
			ELSE 0
		END /*End Weekly*/
	WHEN 0x10 THEN /*Monthly - absolute*/
		CASE WHEN sysschedules.freq_interval = d.DayNumberOfMonth THEN 1 ELSE 0 END
	WHEN 0x20 THEN /*Monthly - Relative*/
		/*Realitive first/second/third/fourth/last instance of specific day of the week*/
		CASE WHEN sysschedules.freq_interval >= 1 and sysschedules.freq_interval <= 7 /*In range for day of week*/
			THEN CASE /*Match the day of week and instance thereof*/
				WHEN d.DayNumberOfWeek = sysschedules.freq_interval AND
					(
					CASE sysschedules.freq_relative_interval
						WHEN 1 then 1/*first*/
						WHEN 2 then 2/*second*/
						WHEN 4 then 3/*third*/
						WHEN 8 then 4/*forth*/
						ELSE -9
					END = d.NumberedInstancesOfDayOfWeekWithinMonth
					OR	CASE WHEN sysschedules.freq_relative_interval = 16 
						AND d.IsLastInstanceOfDayOfWeekWithinMonth = 1 
						THEN 1
						ELSE 0
					END = 1
					)
				THEN 1 /*Successful match for relative day of week*/
				ELSE 0
			END	/*Done looking within relative day of week*/
		WHEN sysschedules.freq_interval = 8 /*Relative any day*/
			THEN CASE WHEN sysschedules.freq_relative_interval = 1 
				AND d.DayNumberOfMonth = 1
					THEN 1 
				WHEN sysschedules.freq_relative_interval = 2
				AND d.DayNumberOfMonth = 2
					THEN 1 
				WHEN sysschedules.freq_relative_interval = 4
				AND d.DayNumberOfMonth = 3
					THEN 1 
				WHEN sysschedules.freq_relative_interval = 8
				AND d.DayNumberOfMonth = 4
					THEN 1 
				WHEN sysschedules.freq_relative_interval = 16
				AND d.IsLastDayOfMonth = 1
					THEN 1 
				ELSE 0 
			END /*Done looking within relative all days of month*/
		WHEN sysschedules.freq_interval = 9 /*Relative week day*/
			THEN CASE WHEN sysschedules.freq_relative_interval = 1 
				AND d.IsWeekDay = 1
				AND d.NumberedWeekDaysAndWeekendDays = 1
					THEN 1 
				WHEN sysschedules.freq_relative_interval = 2
				AND d.IsWeekDay = 1
				AND d.NumberedWeekDaysAndWeekendDays = 2
					THEN 1 
				WHEN sysschedules.freq_relative_interval = 4
				AND d.IsWeekDay = 1
				AND d.NumberedWeekDaysAndWeekendDays = 3
					THEN 1 
				WHEN sysschedules.freq_relative_interval = 8
				AND d.IsWeekDay = 1
				AND d.NumberedWeekDaysAndWeekendDays = 4
					THEN 1 
				WHEN sysschedules.freq_relative_interval = 16
				AND d.IsWeekDay = 1
				AND d.IsLastWeekDayOrWeekendDay = 1
					THEN 1 
				ELSE 0 
			END /*Done looking within relative week days of month*/
		WHEN sysschedules.freq_interval = 10 /*Relative weekend day*/
			THEN CASE WHEN sysschedules.freq_relative_interval = 1 
				AND d.IsWeekend = 1
				AND d.NumberedWeekDaysAndWeekendDays = 1
					THEN 1 
				WHEN sysschedules.freq_relative_interval = 2
				AND d.IsWeekend = 1
				AND d.NumberedWeekDaysAndWeekendDays = 2
					THEN 1 
				WHEN sysschedules.freq_relative_interval = 4
				AND d.IsWeekend = 1
				AND d.NumberedWeekDaysAndWeekendDays = 3
					THEN 1 
				WHEN sysschedules.freq_relative_interval = 8
				AND d.IsWeekend = 1
				AND d.NumberedWeekDaysAndWeekendDays = 4
					THEN 1 
				WHEN sysschedules.freq_relative_interval = 16
				AND d.IsWeekend = 1
				AND d.IsLastWeekDayOrWeekendDay = 1
					THEN 1 
				ELSE 0 
			END /*Done looking within relative week days of month*/		
		ELSE 0 /*Done with Monthly Relative*/
	END
	ELSE 0 /*Done with frequency types*/
END = 1 /*Compare to 1. to filter in or out.*/

/*Then join to tally table based on number of seconds*/
INNER JOIN #Tally q
on q.hhmmss = [sysschedules].active_start_time
AND q.n < 86400
INNER JOIN #Tally t
ON 
t.n < 86400
AND t.HHMMSS >= [sysschedules].active_start_time
AND t.HHMMSS <= [sysschedules].active_end_time
AND CASE [sysschedules].freq_subday_type
	WHEN 0x1 THEN 
		CASE WHEN sysschedules.active_start_time = t.hhmmss THEN 1 ELSE 0 END /*Exact time */
	WHEN 0x2 THEN /* Seconds.*/
		CASE WHEN 
			(t.N - q.N) % sysschedules.freq_subday_interval = 0 THEN 1 ELSE 0 END
			/*Adjust number of seconds based on start time. negative handled by active times*/
	WHEN 0x4 THEN /*Minutes*/
		CASE WHEN 
			(t.N - q.N) % (sysschedules.freq_subday_interval * 60) = 0 THEN 1 ELSE 0 END
			/*Adjust number of seconds based on start time. negative handled by active times*/

	WHEN 0x8 THEN /*Hours*/
		CASE WHEN 
			(t.N - q.N) % (sysschedules.freq_subday_interval * 60 * 60) = 0 THEN 1 ELSE 0 END
			/*Adjust number of seconds based on start time. negative handled by active times*/

	ELSE 0 /*Done with frequency types*/
/*End Seconds*/	
END = 1
)


/**********
***********
***********
End Schedule projection. 
***********
***********
*****/





SELECT JobDurationInformation.[JobName]			
,JobDurationInformation.[Category]			
,JobDurationInformation.[Owner]			
,JobDurationInformation.[Enabled]			
,JobDurationInformation.[Scheduled]		
,JobDurationInformation.[Description]		
,JobDurationInformation.[Occurs]			
,JobDurationInformation.[Occurs_detail]	
,JobDurationInformation.[Frequency]		
,JobDurationInformation.[AvgDurationInSec] 
,JobDurationInformation.[AvgDurationInMin] 
,JobDurationInformation.[ServerName]		
,
	mySchedulesProjected.FullDate
	+ CAST(RIGHT('0' + CAST(mySchedulesProjected.N/3600 AS VARCHAR),2) + ':' +
	+ RIGHT('0' + CAST((mySchedulesProjected.N / 60) % 60 AS VARCHAR),2) + ':' +
	+ RIGHT('0' + CAST(mySchedulesProjected.N  % 60 AS VARCHAR),2) AS TIME)
	AS ProjectedStartTime
,CAST(RIGHT('0' + CAST(CAST(JobDurationInformation.[AvgDurationInSec] AS INT)/3600 AS VARCHAR),2) + ':' +
	+ RIGHT('0' + CAST((CAST(JobDurationInformation.[AvgDurationInSec] AS INT) / 60) % 60 AS VARCHAR),2) + ':' +
	+ RIGHT('0' + CAST(CAST(JobDurationInformation.[AvgDurationInSec] AS INT)  % 60 AS VARCHAR),2) AS TIME)
	AS AvgDurationInSec_RoundedAndCastAsTime
,CAST(RIGHT('0' + CAST(CAST(JobDurationInformation.Duration_MeanPlus2StdDv_RoundedToSecs AS INT)/3600 AS VARCHAR),2) + ':' +
	+ RIGHT('0' + CAST((CAST(JobDurationInformation.Duration_MeanPlus2StdDv_RoundedToSecs AS INT) / 60) % 60 AS VARCHAR),2) + ':' +
	+ RIGHT('0' + CAST(CAST(JobDurationInformation.Duration_MeanPlus2StdDv_RoundedToSecs AS INT)  % 60 AS VARCHAR),2) AS TIME)
	AS Duration_MeanPlus2StdDv_RoundedToSecs
FROM mySchedulesProjected
INNER JOIN #JobDurations AS JobDurationInformation
ON mySchedulesProjected.schedule_id = JobDurationInformation.schedule_id
--where freq_type = 8
ORDER BY JobDurationInformation.JobName
, JobDurationInformation.schedule_id 
, ProjectedStartTime

