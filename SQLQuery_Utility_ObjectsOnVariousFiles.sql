/*
https://blog.sqlauthority.com/2009/06/01/sql-server-list-all-objects-created-on-all-filegroups-in-database/
*/


;with myObjectsOnFiles AS(
/* Get Details of Object on different filegroup
Finding User Created Tables*/
SELECT o.[name] AS ObjectName, o.[type] AS ObjectType, i.[name] AS IndexName, i.[index_id] AS IndexType, I.index_id, f.[name] AS FileName
FROM sys.indexes i
INNER JOIN sys.filegroups f
ON i.data_space_id = f.data_space_id
INNER JOIN sys.all_objects o
ON i.[object_id] = o.[object_id]
WHERE i.data_space_id = f.data_space_id
--AND o.type = 'U' -- User Created Tables
)


SELECT * FROM myObjectsOnFiles Where 

GO 

