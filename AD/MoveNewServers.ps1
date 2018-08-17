# move computers from initial OU to target OU by mask

$targets = @{
    "..." = "OU=...,OU=Servers,DC=...,DC=...";
    "..." = "OU=...,OU=Servers,DC=...,DC=..."; 
    "..." = "OU=...,OU=Servers,DC=...,DC=..."; 
    "..." = "OU=...,OU=Servers,DC=...,DC=..."; 
    "..." = "OU=...,OU=Servers,DC=...,DC=..."
}

Get-ADComputer -Filter {enabled -eq $true} -SearchBase "CN=Computers,DC=...,DC=..." | 
ForEach-Object {
    ForEach($item in $targets.KEYS.GetEnumerator()) {
      IF ($_.name -like $item) {
        #Write-Host $_.name $targets.Get_Item($item)
        Move-ADObject $_ -TargetPath $targets.Get_Item($item)
      }
    }
}
