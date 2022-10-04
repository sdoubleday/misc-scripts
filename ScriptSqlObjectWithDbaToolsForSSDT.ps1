<#
.SYNOPSIS
SSDT Does not like SET options and insists on batch separators.
This scripts an object without file group, with all contraints and keys, with GO batch separators, and without the standard two set options lines you get when scripting an object (ANSI_NULLS and QUOTED_IDENTIFIERS).
These options are suitable if you are bringing table definitions into an SSDT sqlproj file to act as a reference for development of code that relies on those objects but not the rest of an overly-cumbersome source database.
#>

PARAM(
 [String]$objectName
,[String]$objectSchema
,[Microsoft.SqlServer.Management.Smo.Database]$database
)
BEGIN   {
Import-Module dbatools;
$scriptingOptions = New-DbaScriptingOption;
$scriptingOptions.DriAll = $true;
$scriptingOptions.NoFileGroup = $true;
$scriptingOptions.ScriptBatchTerminator = $true;
}<# END BEGIN    #>
PROCESS {
$db.tables[$objectName, $objectSchema] | Export-DbaScript -PassThru -ScriptingOptionsOject $scriptingOptions | Select-Object -Skip 3; <#First object is comments, second and third are set options.#>
}<# END PROCESS  #>
END     {}<# END END      #>

