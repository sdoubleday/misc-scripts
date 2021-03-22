<#
Reverse lookup in active directory - exact match
http://www.markwilson.co.uk/blog/2013/02/searching-active-directory-with-powershell-and-a-users-phone-number.htm
#>

$Search = Read-Host 'What name would you like to search for?'
Get-AdUser -Filter * -Properties GivenName,Surname,OfficePhone,MobilePhone,TelephoneNumber,UserPrincipalName |
Where-Object {$_.SamAccountName -like "*$Search*" -or $_.GivenName -like "*$Search*" `
-or $_.Surname -like "*$Search*"} | `
Format-Table GivenName,Surname,OfficePhone,MobilePhone,TelephoneNumber,UserPrincipalName