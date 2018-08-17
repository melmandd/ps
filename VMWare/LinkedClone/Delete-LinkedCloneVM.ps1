# delete linked clone vm

Param(
    [Parameter(Mandatory=$true)]
    [string]$VMName
)

$mycredentials = Import-Clixml -Path <cred.xml>
Connect-VIServer <ip> -Credential $mycredentials

$vm = $null
$vm = Get-VM $VMName

# Проверяем тег "World" на правильность
# $vm_tags = Get-TagAssignment -Entity $vm | Select-Object -ExpandProperty Tag | Select-Object -ExpandProperty Name

# Если тег "World" и название ВМ соответствуют - выключаем ВМ если она была включена и удаляем её
    if ($vm.PowerState -eq "PoweredOn"){
        Shutdown-VMGuest -VM $VMName -Confirm:$false
    }
    while ($true) {
        $vm = Get-VM $VMName
        if ($vm.PowerState -eq "PoweredOff") {Break}
    }
    # Удаляем ВМ
    Remove-VM -VM $VMName -DeletePermanently:$true -Confirm:$false   
