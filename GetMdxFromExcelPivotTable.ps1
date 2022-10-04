<#
.SYNOPSIS
Open an .xlsx file with excel (silently), get the MDX query used by the Pivot Table on the active sheet, return that, and close the workbook.
#>>

PARAM ([Parameter(Mandatory= $true,ValueFromPipelineByPropertyName= $true)][ValidateNotNullorEmpty()][ValidateScript({
            IF (Test-Path -PathType leaf -Path $_ ) 
                {$True}
            ELSE {
                Throw "$_ is not a file."
            } 
        })][String]$FullName)
BEGIN{}
PROCESS{
$excelApp = New-Object -ComObject 'Excel.Application';
$excelWorkBook = $excelApp.Workbooks.Open($FullName);
$output = $excelWorkBook.ActiveSheet.PivotTables(1).MDX;
$excelWorkBook.Close();

return $output;
}
END {}
