# Delete VM from special folder. Run by Task sheduler
Import-Module VMware.PowerCLI

$usernameVM = <user>
$passwordVM = convertto-securestring -String <password> -AsPlainText -Force
$credVM = new-object -typename System.Management.Automation.PSCredential -argumentlist $usernameVM, $passwordVM
Connect-VIServer -Server <ip> -Credential $credVM

Get-VM -Name * -Location <Folder> | Where-Object -Property Name -Like *_del | Where-Object -Property PowerState -eq PoweredOff #| Format-Table -AutoSize -Property *