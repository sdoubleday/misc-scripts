/*
https://blogs.msdn.microsoft.com/batuhanyildiz/2013/03/02/autogrowth-option-for-sql-server-database-files/
*/
--auto growth percentage for data and log files
select DB_NAME(files.database_id) database_name, files.name logical_name, 
CONVERT (numeric (15,2) , (convert(numeric, size) * 8192)/1048576) [file_size (MB)],
[next_auto_growth_size (MB)] = case is_percent_growth
    when 1 then CONVERT(numeric(18,2), (((convert(numeric, size)*growth)/100)*8)/1024)
    when 0 then CONVERT(numeric(18,2), (convert(numeric, growth)*8)/1024)
end,
is_read_only = case is_read_only 
    when 1 then 'Yes'
    when 0 then 'No'
end,    
is_percent_growth = case is_percent_growth 
    when 1 then 'Yes'
    when 0 then 'No'
end, 
physical_name
from sys.master_files files
where files.type in (0,1)
and files.growth != 0