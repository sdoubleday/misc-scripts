/*sdoubleday
2015-12-15
If you compare the results of this in close succession on session ID, 
Host_name, and Host_process_id, you can probably catch otherwise difficult
to track down 4014 / 10054 connection closed errors. */

select 
DATEDIFF(SECOND,s.login_time, GETDATE()) AS SessionDuration_Seconds
,s.login_name
,s.client_interface_name
,s.program_name
,s.host_name
,s.host_process_id
,s.login_time
,s.session_id
,GETDATE() AS SampleTime
FROM sys.dm_exec_sessions s



