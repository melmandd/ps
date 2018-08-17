#convert linked clone vm to gold image
Param(
    [Parameter(Mandatory=$true)]
    [string]$VMName,

    [Parameter(Mandatory=$false)]
    [string]$VMDescription
)

$mycredentials = Import-Clixml -Path <cred.xml>
Connect-VIServer <ip> -Credential $mycredentials

# Выключаем ВМ если она была включена
$vm = Get-VM $VMName
if ($vm.PowerState -eq "PoweredOn"){
    Shutdown-VMGuest -VM $VMName -Confirm:$false
}
while ($true) {
    $vm = Get-VM $VMName
    if ($vm.PowerState -eq "PoweredOff") {Break}
}

# Меняем имя ВМ на имя+tmp
Set-VM -VM $vm -Name $VMName"tmp" -Confirm:$false
$vm = Get-VM $VMName"tmp"
# Делаем клон ВМ с исходным именем. Клон делается для отвязки от LinkedClone
$vmhost = Get-VMHost -Name <host fqdn>
$myDatastore = Get-Datastore -Name <name>
New-VM -Name $VMName -VM $vm -VMHost $vmhost -Datastore $myDatastore

$vm = Get-VM $VMName

# Создаем эталонный снепшот с названием InitialState
New-Snapshot -VM $vm -Name "InitialState"

# Ставим на ВМ тег GoldImage
Get-VM -Name $vm | New-TagAssignment -Tag "GoldImage"

# Заполняем поле Notes
Set-VM $vm -Notes $VMDescription -Confirm:$false

# Удаляем исходный LinkedClone
Remove-VM -VM $VMName"tmp" -DeletePermanently:$true -Confirm:$false