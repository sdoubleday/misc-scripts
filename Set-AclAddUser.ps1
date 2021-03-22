#Adapted from https://blog.netwrix.com/2018/04/18/how-to-manage-file-system-acls-with-powershell-scripts/
PARAM(
 $path
,$user = "Domain\username"
,$permission = "Modify"
,$allowOrDeny = "Allow"
,$inheritanceFlag = 3
,$propagationFlag = 0
)

$acl = Get-Acl $path

$acl | fl

$AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($user,$permission,$inheritanceFlag,$propagationFlag,$allowOrDeny)

$acl.SetAccessRule($AccessRule)

$acl | fl

$acl | Set-Acl $path




#$acl = Get-Acl $path

#$usersid = New-Object System.Security.Principal.Ntaccount ($user)

#$acl.PurgeAccessRules($usersid)

#$acl | Set-Acl $path

