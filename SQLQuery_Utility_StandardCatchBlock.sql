
SET XACT_Abort ON;
/*
https://social.msdn.microsoft.com/Forums/sqlserver/en-US/8556acc9-79ce-4fd7-9210-50452a6920f6/begin-transaction-within-try-catch-or-vice-versa?forum=transactsql

This will cause execution to bail out after one error. It WILL fire the catch block.
It will also close the transaction, which is important if you hit a validation error,
such as if a table has changed or been dropped - otherwise you can wind up with open transactions
See Erland Sommarskog's comment for confirmation of why this is.
*/


/*
BEGIN TRY
    BEGIN TRANSACTION
    /*================================================
     Add Your Code Here
    ================================================*/
    COMMIT
END TRY
BEGIN CATCH
	ROLLBACK
END CATCH

*/
BEGIN TRY

Begin Transaction /*OPTIONALNAME */

COMMIT TRANSACTION /*OPTIONALNAME*/

END TRY


BEGIN CATCH 
	DECLARE 
	 @ErrorNumber	 INT
	,@ErrorSeverity	 INT
	,@ErrorState	 INT
	,@ErrorProcedure	 NVARCHAR(4000)
	,@ErrorLine		 INT
	,@ErrorMessage	 NVARCHAR(4000)

	SELECT
		@ErrorNumber	= ERROR_NUMBER() ,
		@ErrorSeverity	= ERROR_SEVERITY() ,
		@ErrorState		= ERROR_STATE() ,
		@ErrorProcedure = ERROR_PROCEDURE() ,
		@ErrorLine		= ERROR_LINE() ,
		@ErrorMessage	= ERROR_MESSAGE() ;
	
	RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState, @ErrorNumber,@ErrorLine)
		
	ROLLBACK Transaction /*OPTIONALNAME*/
	RETURN
END CATCH
