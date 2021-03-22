<#
Reverse lookup in active directory - exact match
http://www.markwilson.co.uk/blog/2013/02/searching-active-directory-with-powershell-and-a-users-phone-number.htm
#>

$Search = Read-Host 'What number would you like to search for?'
Get-AdUser -Filter * -Properties OfficePhone,MobilePhone,TelephoneNumber |
Where-Object {$_.OfficePhone -match $Search -or $_.MobilePhone -match
$Search -or $_.TelephoneNumber -match $Search} |
Format-Table GivenName,Surname,OfficePhone,MobilePhone,TelephoneNumber