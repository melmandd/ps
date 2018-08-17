# upload list of vm snapshots older 30 days to Atlassian Confluence page
Import-Module VMware.PowerCLI
Import-Module ConfluencePS

$usernameVM = <vsphere user>
$passwordVM = convertto-securestring -String <vsphere pass> -AsPlainText -Force
$credVM = new-object -typename System.Management.Automation.PSCredential -argumentlist $usernameVM, $passwordVM
Connect-VIServer -Server <ip> -Credential $credVM

$username = <confluence user>
$password = convertto-securestring -String <confluence password> -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $password

Set-WikiInfo -BaseURI <confluence uri> -Credential $cred

$delta = (Get-Date).AddDays(-30)

#Добавляет модуль HTML разметики на страницу.

$Modulbody = '<a href="#page-metadata-start" class="assistive">Переход к началу метаданных</a>
<div id="page-metadata-end" class="assistive"></div>

        
                                            
        <div id="main-content" class="wiki-content">
                           
        <p><br/></p>'

        $bodyVM = Get-vm | Get-Snapshot | Where-Object -Property Created -LT ($delta) | Select-Object `
        @{n="VM";e={$_.VM}},`
        @{n="Created";e={$_.Created}},` 
        @{n="SizeGB"; e = {[math]::Round($_.SizeGB,1)}},`
        @{n="Name";e={$_.Name}},`
        @{n="PowerState";e={$_.PowerState}} | Sort-Object -Property SizeGB -Descending

# Get-vm | Get-Snapshot | Where-Object -Property Created -LT ($delta) | Format-Table -Property Created, @{Label="SizeGB"; Expression = {[math]::Round($_.SizeGB,1)}}, Name, PowerState

$bodyVMHTML = $bodyVM | ConvertTo-HTML

#Закрывается модуль HTML разметки

$bodyEnd = '

</div>'

#Удаляем лишнее из полученного списка, конфлюенс ругается на данный код, нам нужна чисто HTML таблица.

$Out = $bodyVMHTML `
-replace '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">' `
-replace '<html xmlns="http://www.w3.org/1999/xhtml">' `
-replace '<head>' `
-replace '<title>HTML TABLE</title>' `
-replace '</head><body>' `
-replace '</body></html>'

$bodyOut = $Modulbody + $Out + $bodyEnd 

Set-WikiPage -PageID <page id> -Title <page title> -Body "$bodyOut"