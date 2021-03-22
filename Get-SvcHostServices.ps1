<#
 .Synopsis
  Provide a report on all SvcHost processes and embedded services. Taken from Chris O?Prey 
  guest post on Scripting Guy blog.
 
 .Description
  Gets the details on all services running inside of SvcHost processes along with memory
  consumption, page faults and command lines.

  Updates - 2015-10-05 Scott Doubleday-Stern added a parameter for Process ID.
 
 .Parameter computer
  The machine to test. Defaults to the current machine.
 
 .Parameter outHTML
  A switch. Will return a HTML formatted output of the process & service details.
 
 .Parameter outGrid
  A switch. Will return a GridView formatted output of the process & service details.

 .PARAMETER ProcessID
  Optional Integer parameter. If provided, will only return embedded services for that particular SvcHost process ID.
  If that process ID is not an SvcHost process, returns error.
 
 .INPUTS
  None. You cannot pipe objects to Invoke-Task.
 
 .OUTPUTS
  A collection of PSObjects containing the details of each service.
 
 .Example
   Get-ServiceDetails
   Gets the details for the current machine as a PSObject collection.
 
 .Example
   Get-ServiceDetails "SERVER-001"
   Gets the details for the given machine as a PSObject collection.
 
 .Example
   Get-ServiceDetails -outHTML
   Gets the details for the current machine as a PSObject collection and also displays the details in
   the current browser as an HTML formatted file. This file is also persisted to the current folder.
 
 .Example
   Get-ServiceDetails -outGrid
   Gets the details for the current machine as a PSObject collection and also displays the details in
   a GridView.

 .LINK
   http://blogs.technet.com/b/heyscriptingguy/archive/2011/04/21/expert-solution-for-2011-scripting-games-advanced-event-4-use-powershell-to-find-services-hiding-in-the-svchost-process.aspx

#>
 
param (
    [string]$computer = ".",
    [switch]$outHTML,
    [switch]$outGrid
    ,[int]$ProcessID
)
IF ($PSBoundParameters.ContainsKey('ProcessID')) {
    $filter = "Name='svchost.exe' AND ProcessID = '$ProcessID'"
}<#End If ProcessID is present#>
ELSE {
    $filter = "Name='svchost.exe'"
}

$results = (Get-WmiObject -Class Win32_Process -ComputerName $computer -Filter $filter | % {
    
    $process = $_ 

    Get-WmiObject -Class Win32_Service -ComputerName $computer -Filter "ProcessId=$($_.ProcessId)" | % {
        New-Object PSObject -Property @{ProcessId=$process.ProcessId;
                                        CommittedMemory=$process.WS;
                                        PageFaults=$process.PageFaults;
                                        CommandLine=$_.PathName;
                                        ServiceName=$_.Name;
                                        State=$_.State;
                                        DisplayName=$_.DisplayName;
                                        StartMode=$_.StartMode}
    }
})

if($results -eq $null -AND $PSBoundParameters.ContainsKey('ProcessID')) {
    THROW "No SvcHost.exe processes are running with process ID $ProcessID"
}
ELSEIF ($results -eq $null){
    THROW "No SvcHost.exe processes are running"
}
 
if ($outHTML)
{
    $results | ConvertTo-Html | Out-File ".\temp.html"
    & .\temp.html
}
 
if ($outGrid)
{
    $results | Out-GridView
}
 
$results
