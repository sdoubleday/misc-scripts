


##Blog I took this from with some mild adjustments:
## http://blog.pluralsight.com/powershell-to-read-emails


##This code chunk does two things: 
##it demonstrates how to access a local outlook inbox
##and it DICTATES YOUR EMAIL!

 $olFolderInbox = 6
 $outlook = new-object -com outlook.application;
 $ns = $outlook.GetNameSpace("MAPI");
 $inbox = $ns.GetDefaultFolder($olFolderInbox)
 #checks 1 newest messages
 $inbox.items | select -first 1 | foreach {
         $mBody = $_.body
         #Splits the line before any previous replies are loaded
         $mBodySplit = $mBody -split "From:"
         #Assigns only the first message in the chain
         $mBodyLeft = $mbodySplit[0]
         #build a string using the ?f operator
         $q = "From: " + $_.SenderName + ("`n") + " Message: " + $mBodyLeft
         #create the COM object and invoke the Speak() method 
         (New-Object -ComObject SAPI.SPVoice).Speak($q) | Out-Null
 }
