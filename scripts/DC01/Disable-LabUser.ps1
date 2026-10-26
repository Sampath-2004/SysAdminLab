param(
    [Parameter(Mandatory = $true)]
    [string]$Username
)

$ErrorActionPreference = "Stop"
Import-Module ActiveDirectory
$User = Get-ADUser -Identity $Username
$LabOU = "OU=LabUsers,DC=corp,DC=sampath,DC=test"

if ($User.DistinguishedName -notlike "*,$LabOU") {
    throw "The account must be in LabUsers."
}

Disable-ADAccount -Identity $User
Get-ADUser -Identity $User | Select-Object SamAccountName,Enabled
