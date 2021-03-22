-- Individual File Size query

USE tempdb /*Pick your database*/
GO

SELECT name AS 'File Name' , physical_name AS 'Physical Name', size/128 AS 'Total Size in MB',

size/128.0 - CAST(FILEPROPERTY(name, 'SpaceUsed') AS int)/128.0 AS 'Available Space In MB', *

FROM sys.database_files;


