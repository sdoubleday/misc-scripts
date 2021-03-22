
/*
For size of tables plus indecies on disk
http://stackoverflow.com/questions/7892334/get-size-of-all-tables-in-database*/

Declare @myTables TABLE (blah varchar(1000))
INSERT INTO @myTables VALUES 
	 ('ListTargetTablesHere')


SELECT 
	 t.NAME AS TableName
    ,s.Name AS SchemaName
    ,p.rows AS RowCounts
    ,SUM(a.total_pages) * 8 AS TotalSpaceKB
    ,cast((SUM(a.total_pages) * 8 ) as decimal(19,4)) /1024.0 AS TotalSpaceMB
    ,cast((SUM(a.total_pages) * 8 ) as decimal(19,4)) /1024.0/1024.0 AS TotalSpaceGB
    ,SUM(a.used_pages) * 8 AS UsedSpaceKB
    ,(SUM(a.total_pages) - SUM(a.used_pages)) * 8 AS UnusedSpaceKB
FROM 
    sys.tables t
INNER JOIN      
    sys.indexes i ON t.OBJECT_ID = i.object_id
INNER JOIN 
    sys.partitions p ON i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
INNER JOIN 
    sys.allocation_units a ON p.partition_id = a.container_id
LEFT OUTER JOIN 
    sys.schemas s ON t.schema_id = s.schema_id
WHERE 
    t.NAME in ( SELECT * FROM @myTables)
    AND t.is_ms_shipped = 0
    AND i.OBJECT_ID > 255 
GROUP BY 
    t.Name, s.Name,p.rows 
ORDER BY 
    t.Name



SELECT 
	 SUM(a.total_pages) * 8 AS TotalSpaceKB
    ,cast((SUM(a.total_pages) * 8 ) as decimal(19,4)) /1024.0 AS TotalSpaceMB
    ,cast((SUM(a.total_pages) * 8 ) as decimal(19,4)) /1024.0/1024.0 AS TotalSpaceGB
    ,SUM(a.used_pages) * 8 AS UsedSpaceKB
    ,(SUM(a.total_pages) - SUM(a.used_pages)) * 8 AS UnusedSpaceKB
FROM 
    sys.tables t
INNER JOIN      
    sys.indexes i ON t.OBJECT_ID = i.object_id
INNER JOIN 
    sys.partitions p ON i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
INNER JOIN 
    sys.allocation_units a ON p.partition_id = a.container_id
LEFT OUTER JOIN 
    sys.schemas s ON t.schema_id = s.schema_id
WHERE 
	t.NAME in ( SELECT * FROM @myTables)
    AND t.is_ms_shipped = 0
    AND i.OBJECT_ID > 255 
