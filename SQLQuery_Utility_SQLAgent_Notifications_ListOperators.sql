USE msdb
GO
/*
sdoubleday 2015-10-14
List the email operators for each enabled job*/

select j.name AS JobName
, o_email.name AS EmailName 
, o_page.name as PageName
, o_netsend.name as NetSendName
from dbo.sysjobs j
left outer join dbo.sysoperators o_email
on j.notify_email_operator_id = o_email.id
left outer join dbo.sysoperators o_page
on j.notify_page_operator_id = o_page.id
left outer join dbo.sysoperators o_netsend
on j.notify_page_operator_id = o_netsend.id

where j.enabled = '1'