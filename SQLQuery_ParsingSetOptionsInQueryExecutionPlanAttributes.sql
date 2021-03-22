/*Plug in a plan handle, filter to just attribute = 'set_options' then plug it in here.
sys.dm_exec_plan_attributes(plan_handle)
*/
DECLARE @set_options_value INT = 4347
PRINT 'Set options for value ' + CAST(@set_options_value AS VARCHAR)+ ':'
IF @set_options_value & 1 = 1 PRINT 'ANSI_PADDING'
IF @set_options_value & 2 = 1 PRINT 'Parallel Plan'
IF @set_options_value & 4 = 4 PRINT 'FORCEPLAN'
IF @set_options_value & 8 = 8 PRINT 'CONCAT_NULL_YIELDS_NULL'
IF @set_options_value & 16 = 16 PRINT 'ANSI_WARNINGS'
IF @set_options_value & 32 = 32 PRINT 'ANSI_NULLS'
IF @set_options_value & 64 = 64 PRINT 'QUOTED_IDENTIFIER'
IF @set_options_value & 128 = 128 PRINT 'ANSI_NULL_DFLT_ON'
IF @set_options_value & 256 = 256 PRINT 'ANSI_NULL_DFLT_OFF'
IF @set_options_value & 512 = 512 PRINT 'NoBrowseTable'
IF @set_options_value & 1024 = 1024 PRINT 'TriggerOneRow'
IF @set_options_value & 2048 = 2048 PRINT 'ResyncQuery'
IF @set_options_value & 4096 = 4096 PRINT 'ARITHABORT'
IF @set_options_value & 8192 = 8192 PRINT 'NUMERIC_ROUNDABORT'
IF @set_options_value & 16384 = 16384 PRINT 'DATEFIRST'
IF @set_options_value & 32768 = 32768 PRINT 'DATEFORMAT'
IF @set_options_value & 65536 = 65536 PRINT 'LanguageId'
IF @set_options_value & 131072 = 131072 PRINT 'UPON'