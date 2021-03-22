<#
A demonstration of how to return a failure exit code when invoking powershell in, say, Task Scheduler.
As discussed on stack overflow by Kevin Richardson: https://stackoverflow.com/a/15779295
#>

PARAM(
[parameter(mandatory=$true)]$aThing = 'Silly Default'
,[switch]$bob
)
TRAP {
    Write-Verbose "This trap block is required to pass up failure exit codes when using this syntax: powershell.exe -file 'C:\mysample.ps1' "
    Write-output "Error trapped: "
    Write-Output $_ <#DO NOT throw this error - that will end execution and we will not make it to the exit code.#>    
    exit 1

}

write-output "Ho Hum"
Write-output $aThing
IF($bob.IsPresent) {echo 'bob switch'}
THrow "ZOMG AN ERRROR!"
