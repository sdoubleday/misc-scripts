/* https://www.sqlservercentral.com/blogs/help-i-need-a-list-of-my-maintenance-plan-jobs-and-schedules */


/*
Backup information from maintenance plans - jobs, schedules, etc.

Andy Galbraith @DBA_ANDY

MSSQL 2005+

Heavily borrows from http://sqlfool.com/2009/02/view-sql-agent-jobs-tsql/
for the original job schedule CTE and base query - thanks Michelle!

I modified Michelle's original query slightly and then added
the maintenance plan information to match the jobs to their
parent maintenance plans.

The filter that makes the query relevant to backup subplans is:

"and smpld.line1 like '%Back Up%'"

Commenting out or removing this line will display information about
all maintenance plan subplans and their enabled jobs
*/

Declare @weekDay Table
(
    mask  int
    , maskValue varchar(32)
);

Insert Into @weekDay
    Select 1, 'Sunday'  UNION ALL
    Select 2, 'Monday'  UNION ALL
    Select 4, 'Tuesday'  UNION ALL
    Select 8, 'Wednesday'  UNION ALL
    Select 16, 'Thursday'  UNION ALL
    Select 32, 'Friday'  UNION ALL
    Select 64, 'Saturday';

With myCTE
As (
    Select sched.name As 'scheduleName'
    , sched.schedule_id
    , jobsched.job_id
    , Case
        When sched.freq_type = 1
            Then 'Once'
        When sched.freq_type = 4 And sched.freq_interval = 1
            Then 'Daily'
        When sched.freq_type = 4
            Then 'Every ' + Cast(sched.freq_interval As varchar(5)) + ' days'
        When sched.freq_type = 8
            Then Replace( Replace( Replace((
                Select maskValue
                From @weekDay As x
                Where sched.freq_interval & x.mask <> 0
                Order By mask For XML Raw)
    , '"/><row maskValue="', ', '), '<row maskValue="', ''), '"/>', '')
        + Case When sched.freq_recurrence_factor <> 0
        And sched.freq_recurrence_factor = 1
            Then '; weekly'
    When sched.freq_recurrence_factor <> 0
            Then '; every '
            + Cast(sched.freq_recurrence_factor As varchar(10)) + ' weeks'
        End
        When sched.freq_type = 16
            Then 'On day '
            + Cast(sched.freq_interval As varchar(10)) + ' of every '
            + Cast(sched.freq_recurrence_factor As varchar(10)) + ' months'
        When sched.freq_type = 32
            Then Case
            When sched.freq_relative_interval = 1
                Then 'First'
            When sched.freq_relative_interval = 2
                Then 'Second'
            When sched.freq_relative_interval = 4
                Then 'Third'
            When sched.freq_relative_interval = 8
                Then 'Fourth'
            When sched.freq_relative_interval = 16
                Then 'Last'
    End +
    Case
        When sched.freq_interval = 1
            Then ' Sunday'
        When sched.freq_interval = 2
            Then ' Monday'
        When sched.freq_interval = 3
            Then ' Tuesday'
        When sched.freq_interval = 4
            Then ' Wednesday'
        When sched.freq_interval = 5
            Then ' Thursday'
        When sched.freq_interval = 6
            Then ' Friday'
        When sched.freq_interval = 7
            Then ' Saturday'
        When sched.freq_interval = 8
            Then ' Day'
        When sched.freq_interval = 9
            Then ' Weekday'
        When sched.freq_interval = 10
            Then ' Weekend'
    End
    +
    Case
        When sched.freq_recurrence_factor <> 0
        And sched.freq_recurrence_factor = 1
            Then '; monthly'
        When sched.freq_recurrence_factor <> 0
            Then '; every '
    + Cast(sched.freq_recurrence_factor As varchar(10)) + ' months'
    End
    When sched.freq_type = 64
        Then 'StartUp'
    When sched.freq_type = 128
        Then 'Idle'
     End As 'frequency'
    , IsNull('Every ' + Cast(sched.freq_subday_interval As varchar(10)) +
    Case
        When sched.freq_subday_type = 2
            Then ' seconds'
        When sched.freq_subday_type = 4
            Then ' minutes'
        When sched.freq_subday_type = 8
            Then ' hours'
    End, 'Once') As 'subFrequency'
    , Replicate('0', 6 - Len(sched.active_start_time))
        + Cast(sched.active_start_time As varchar(6)) As 'startTime'
    , Replicate('0', 6 - Len(sched.active_end_time))
        + Cast(sched.active_end_time As varchar(6)) As 'endTime'
    , Replicate('0', 6 - Len(jobsched.next_run_time))
        + Cast(jobsched.next_run_time As varchar(6)) As 'nextRunTime'
    , Cast(jobsched.next_run_date As char(8)) As 'nextRunDate'
    From msdb.dbo.sysschedules As sched
    Join msdb.dbo.sysjobschedules As jobsched
    On sched.schedule_id = jobsched.schedule_id
    Where sched.enabled = 1
)
Select DISTINCT p.name as 'Maintenance_Plan'
, p.[owner] as 'Plan_Owner'
, sp.subplan_name as 'Subplan_Name'
, smpld.line3 as 'Database_Names'
, RIGHT(smpld.line4,LEN(smpld.line4)-6) as 'Backup_Type'
, job.name As 'Job_Name'
, sched.frequency as 'Schedule_Frequency'
, sched.subFrequency as 'Schedule_Subfrequency'
, SubString(sched.startTime, 1, 2) + ':'
    + SubString(sched.startTime, 3, 2) + ' - '
    + SubString(sched.endTime, 1, 2) + ':'
    + SubString(sched.endTime, 3, 2)
As 'Schedule_Time' -- HH:MM
, SubString(sched.nextRunDate, 1, 4) + '/'
    + SubString(sched.nextRunDate, 5, 2) + '/'
    + SubString(sched.nextRunDate, 7, 2) + ' '
    + SubString(sched.nextRunTime, 1, 2) + ':'
    + SubString(sched.nextRunTime, 3, 2)
As 'Next_Run_Date'
/*
Note: the sysjobschedules table refreshes every 20 min,
so Next_Run_Date may be out of date
*/
From msdb.dbo.sysjobs As job
LEFT OUTER Join myCTE As sched
On job.job_id = sched.job_id
LEFT OUTER join  msdb.dbo.sysmaintplan_subplans sp
on sp.job_id = job.job_id
inner join msdb.dbo.sysmaintplan_plans p
on p.id = sp.plan_id
LEFT OUTER JOIN msdb.dbo.sysjobschedules sjs
ON job.job_id = sjs.job_id
INNER JOIN msdb.dbo.sysschedules ss
ON sjs.schedule_id = ss.schedule_id
LEFT OUTER join msdb.dbo.sysmaintplan_log smpl
on p.id = smpl.plan_id
and sp.subplan_id =smpl.subplan_id
LEFT OUTER join msdb.dbo.sysmaintplan_logdetail smpld
on smpl.task_detail_id=smpld.task_detail_id
and smpld.line1 like '%Back Up%'
where job.[enabled] = 1
and smpld.line3<>''
Order By Next_Run_Date;
