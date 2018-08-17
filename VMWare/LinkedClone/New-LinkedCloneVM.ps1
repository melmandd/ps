# create linked clone vm from gold image
Param(
    [Parameter(Mandatory=$true)]
    [string]$VMGoldName,

    [Parameter(Mandatory=$true)]
    [string]$World,

    [Parameter(Mandatory=$false)]
    [string]$VMDescription
)

# Функция ожидает начала кастомизации
Function Get-CustomizationStarted([string] $VM)
{
    Write-Host "Verifying that Customization for VM $VM has started"
    $i=60 #time-out of 5 min
	while($i -gt 0)
	{
		$vmEvents = Get-VIEvent -Entity $VM
		$startedEvent = $vmEvents | Where-Object { $_.GetType().Name -eq "CustomizationStartedEvent" }
		if ($startedEvent)
		{
            #Write-Host  "Customization for VM $VM has started" 
			return $true
		}
		else
		{
			Start-Sleep -Seconds 5
            $i--
		}
	}
    #Write-Warning "Customization for VM $VM has failed"
    return $false
}

# Функция ожидает окончания кастомизации
Function Get-CustomizatonFinished([string] $VM)
{
    #Write-Host  "Verifying that Customization for VM $VM has finished" 
    $i = 60 #time-out of 5 min
	while($true)
	{
		$vmEvents = Get-VIEvent -Entity $VM
		$SucceededEvent = $vmEvents | Where-Object { $_.GetType().Name -eq "CustomizationSucceeded" }
        $FailureEvent = $vmEvents | Where-Object { $_.GetType().Name -eq "CustomizationFailed" }
		if ($FailureEvent -or ($i -eq 0))
		{
			#Write-Warning  "Customization of VM $VM failed" 
            return $False
		}
		if ($SucceededEvent)
		{
            #Write-Host  "Customization of VM $VM Completed Successfully" 
            Start-Sleep -Seconds 30
            #Write-Host  "Waiting for VM $VM to complete post-customization reboot" 
            Wait-Tools -VM $VM -TimeoutSeconds 300
            Start-Sleep -Seconds 30
            return $true
		}
        Start-Sleep -Seconds 5
        $i--
	}
}

# Создание LinkedClone указанного мастер-образа

# Add-PSSnapin "VMware.VimAutomation.Core"
# Import-Module VMware.PowerCLI | Out-Null

$usernameVM = <user>
$passwordVM = convertto-securestring -String <password> -AsPlainText -Force
$mycredentials = new-object -typename System.Management.Automation.PSCredential -argumentlist $usernameVM, $passwordVM
Connect-VIServer <ip> -Credential $mycredentials | Out-Null

# Ищем следующее свободное имя ВМ на DHCP сервере

$new_VMName = $null

# Если Win
if ($VMGoldName -like <mask>) {
    # Берем список имен ВМ с кластера
    $cluster_vms = Get-VM * | Where-Object -Property Name -Like <mask>
    # и с DHCP сервера и выбираем следующее свободное
    $used_hostnames = Get-DhcpServerv4Lease -ComputerName <ip dhcp> -ScopeId <scope id> | Where-Object -Property HostName -like <mask>
    for ($i = 1; $i -lt 501; $i++) {
        $new_VMName = <mask> + $i.ToString("000")
        $new_VMNameFQDN = $new_VMName  + "..."
        if (($used_hostnames.HostName.Contains($new_VMNameFQDN)) -OR ($cluster_vms.Name.Contains($new_VMName))) {Continue}
        Break
    }
}

# Если nix
if ($VMGoldName -like "mask") {

    # Берем список имен ВМ с кластера
    $cluster_vms = Get-VM * | Where-Object -Property Name -Like "mask"
    # и с DHCP сервера и выбираем следующее свободное
    $used_hostnames = Get-DhcpServerv4Lease -ComputerName <ip dhcp> -ScopeId <scope id> | Where-Object -Property HostName -like mask
    for ($i = 1; $i -lt 501; $i++) {
        $new_VMName = "mask" + $i.ToString("000")
        $new_VMNameFQDN = $new_VMName  + "..."
        if (($used_hostnames.HostName.Contains($new_VMNameFQDN)) -OR ($cluster_vms.Name.Contains($new_VMName))) {Continue}
        Break
    }
}

# Если ABS
if ($VMGoldName -like "mask") {

    # Берем список имен ВМ с кластера
    $cluster_vms = Get-VM * | Where-Object -Property Name -Like "mask"
    # и с DHCP сервера и выбираем следующее свободное
    $used_hostnames = Get-DhcpServerv4Lease -ComputerName <ip dhcp> -ScopeId <scope id> | Where-Object -Property HostName -like mask
    for ($i = 1; $i -lt 501; $i++) {
        $new_VMName = "mask" + $i.ToString("000")
        $new_VMNameFQDN = $new_VMName  + "..."
        if (($used_hostnames.HostName.Contains($new_VMNameFQDN)) -OR ($cluster_vms.Name.Contains($new_VMName))) {Continue}
        Break
    }
}

#$new_VMName = $new_VMName.Split(".")[0]

# Если новое имя нашлось, продолжаем
if ($new_VMName){

    # Берем у золотого образа опорный снепшот InitialState
    $mySourceVM = Get-VM -Name $VMGoldName
    $myReferenceSnapshot = Get-Snapshot -VM $mySourceVM -Name "InitialState"
    # Указываем хост и стору для размещения новой ВМ
    $vmhost = Get-VMHost -Name "esxi fqdn"
    $myDatastore = Get-Datastore -Name "datastore name" 
    
    # Создаем LinkedClone
    # Если это АБС
    if ($new_VMName -like "mask"){
        # Берем скрипт кастомизации ABS
        $mySpecification = Get-OSCustomizationSpec -Name ABS
        # Создаем linked-clone ВМ с кастомизацией
        New-VM -Name $new_VMName -VM $mySourceVM -LinkedClone -ReferenceSnapshot $myReferenceSnapshot -ResourcePool $vmhost -Datastore $myDatastore -OSCustomizationSpec $mySpecification | Out-Null
        New-AdvancedSetting -Entity (Get-VM -Name $new_VMName) -Name guestinfo.vmname -Value $new_VMName -Confirm:$false
        # Запускаем ВМ
        Start-VM -VM $new_VMName 
        # Подключаем сетевой адаптер
        Get-VM $new_VMName | Get-NetworkAdapter | Set-NetworkAdapter -Connected:$true -Confirm:$false
        # Ждем завершения загрузки
        Get-VM $new_VMName | Wait-Tools -TimeoutSeconds 600
        # Запускаем скрипт кастомизации (пока нифига не работает почему то, зависает на инвоке)
        Invoke-VMScript -VM $new_VMName -ScriptText "sh afterdeploy.sh" -GuestUser <> -GuestPassword <> -ScriptType Bash
    }    

    # Если Win
    if ($new_VMName -like "wrudc1dev*") {
        # Берем скрипт кастомизации WS2016_Domain
        $mySpecification = Get-OSCustomizationSpec -Name WS2016_Domain
        New-VM -Name $new_VMName -VM $mySourceVM -LinkedClone -ReferenceSnapshot $myReferenceSnapshot -ResourcePool $vmhost -Datastore $myDatastore -OSCustomizationSpec $mySpecification
        New-AdvancedSetting -Entity (Get-VM -Name $new_VMName) -Name guestinfo.vmname -Value $new_VMName -Confirm:$false
        Get-VM $new_VMName | Get-NetworkAdapter | Set-NetworkAdapter -StartConnected:$true -Confirm:$false
        # Запускаем новую ВМ и ожидаем загрузки Tools. Затем кастомизируем её и перезагружаем
        Start-VM -VM $new_VMName
        #Invoke-VMScript -VM $new_VMName -ScriptType Powershell -ScriptText "Rename-Computer -NewName $new_VMName -Restart" -GuestUser Administrator -GuestPassword PwdUfa123
        # Ожидаем окончания кастомизации
        Get-CustomizationStarted($new_VMName)
        Get-CustomizatonFinished($new_VMName)
        Get-VM $new_VMName | Wait-Tools
    }
        
    # Если nix
    if ($new_VMName -like "mask") {
        New-VM -Name $new_VMName -VM $mySourceVM -LinkedClone -ReferenceSnapshot $myReferenceSnapshot -ResourcePool $vmhost -Datastore $myDatastore
        New-AdvancedSetting -Entity (Get-VM -Name $new_VMName) -Name guestinfo.vmname -Value $new_VMName -Confirm:$false
        Get-VM $new_VMName | Get-NetworkAdapter | Set-NetworkAdapter -StartConnected:$true -Confirm:$false
        # Запускаем новую ВМ и ожидаем загрузки Tools. Затем кастомизируем её и перезагружаем
        Start-VM -VM $new_VMName 
        Get-VM $new_VMName | Wait-Tools -TimeoutSeconds 600
        $script_text = "sh custom.sh $new_VMName"
        Invoke-VMScript -VM $new_VMName -ScriptText $script_text -GuestUser <> -GuestPassword <> -ScriptType Bash
        Start-Sleep -s 10
        Get-VM $new_VMName | Wait-Tools -TimeoutSeconds 600
    }
    
     # Создаем теги с именем мира и названием ВМ золотого образа и назначаем их для новой ВМ
    New-Tag -Name $World -Category "WorldName"
    New-Tag -Name $VMGoldName -Category "GoldImage"
    $tagWorld = Get-Tag $World
    $tagVMGoldName = Get-Tag $VMGoldName
    Get-VM -Name $new_VMName | New-TagAssignment -Tag $tagWorld
    Get-VM -Name $new_VMName | New-TagAssignment -Tag $tagVMGoldName
}