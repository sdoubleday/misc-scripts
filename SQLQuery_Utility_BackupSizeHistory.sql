/*From http://gallery.technet.microsoft.com/scriptcenter/ec6abcda-e451-4863-92ed-8648fdfc67ac#content*/

/*Edited by sdoubleday 2015-10-07 to actually work.
Was using the backupfile table, which lists one row per database file. Everything
we needed was in backupset. Also, now using GB. Because nothing I care about is measured in MB.*/

-- Transact-SQL script to analyse the database size growth using backup history. 
DECLARE @startDate datetime; 
SET @startDate = GetDate(); 
 
SELECT PVT.DatabaseName AS DatabaseName_MonthsAgo_DbBakAvgSize
      , PVT.[0], PVT.[-1], PVT.[-2], PVT.[-3],  PVT.[-4],  PVT.[-5],  PVT.[-6] 
               , PVT.[-7], PVT.[-8], PVT.[-9], PVT.[-10], PVT.[-11], PVT.[-12] 
FROM 
   (SELECT BS.database_name AS DatabaseName 
          ,DATEDIFF(mm, @startDate, BS.backup_start_date) AS MonthsAgo 
          ,AVG(CONVERT(numeric(32, 4), bs.backup_size) ) / 1024.0 / 1024.0 / 1024.0 AS AvgSizeGB 
    FROM msdb.dbo.backupset as BS 
    WHERE /*
    NOT BS.database_name IN 
              ('master', 'msdb', 'model', 'tempdb') 
          AND  */
          bs.Type = 'D' 
          AND BS.backup_start_date BETWEEN DATEADD(yy, -1, @startDate) AND @startDate 
    GROUP BY BS.database_name 
            ,DATEDIFF(mm, @startDate, BS.backup_start_date) 
    ) AS BCKSTAT 
PIVOT (SUM(BCKSTAT.AvgSizeGB) 
       FOR BCKSTAT.MonthsAgo IN ([0], [-1], [-2], [-3], [-4], [-5], [-6], [-7], [-8], [-9], [-10], [-11], [-12]) 
      ) AS PVT 
ORDER BY PVT.DatabaseName;

go
/*2015-10-07 A version for Days Ago*/
DECLARE @startDate datetime; 
SET @startDate = GetDate(); 
 
SELECT PVT.DatabaseName AS DatebaseName_DaysAgo_DbBakAvgSize
      ,PVT.[0],PVT.[-1],PVT.[-2],PVT.[-3],PVT.[-4],PVT.[-5],PVT.[-6],PVT.[-7],PVT.[-8],PVT.[-9],PVT.[-10],PVT.[-11],PVT.[-12],PVT.[-13],PVT.[-14],PVT.[-15],PVT.[-16],PVT.[-17],PVT.[-18],PVT.[-19],PVT.[-20],PVT.[-21],PVT.[-22],PVT.[-23],PVT.[-24],PVT.[-25],PVT.[-26],PVT.[-27],PVT.[-28],PVT.[-29],PVT.[-30],PVT.[-31],PVT.[-32],PVT.[-33],PVT.[-34],PVT.[-35],PVT.[-36],PVT.[-37],PVT.[-38],PVT.[-39]
 
FROM 
   (SELECT BS.database_name AS DatabaseName 
          ,DATEDIFF(DAY, @startDate, BS.backup_start_date) AS DaysAgo 
          ,AVG(CONVERT(numeric(32, 4), bs.backup_size) ) / 1024.0 / 1024.0 / 1024.0 AS AvgSizeGB 
    FROM msdb.dbo.backupset as BS 
    WHERE /*
    NOT BS.database_name IN 
              ('master', 'msdb', 'model', 'tempdb') 
          AND  */
          bs.Type = 'D' 
          AND BS.backup_start_date BETWEEN DATEADD(DAY, -39, @startDate) AND @startDate 
    GROUP BY BS.database_name 
            ,DATEDIFF(DAY, @startDate, BS.backup_start_date) 
    ) AS BCKSTAT 
PIVOT (SUM(BCKSTAT.AvgSizeGB) 
       FOR BCKSTAT.DaysAgo IN ([0],[-1],[-2],[-3],[-4],[-5],[-6],[-7],[-8],[-9],[-10],[-11],[-12],[-13],[-14],[-15],[-16],[-17],[-18],[-19],[-20],[-21],[-22],[-23],[-24],[-25],[-26],[-27],[-28],[-29],[-30],[-31],[-32],[-33],[-34],[-35],[-36],[-37],[-38],[-39]
) 
      ) AS PVT 
ORDER BY PVT.DatabaseName;