$ErrorActionPreference = "Stop"
Import-Module ActiveDirectory

$OU = "OU=LabUsers,DC=corp,DC=sampath,DC=test"
$Groups = @{
    IT = "GG_IT_Users"
    HR = "GG_HR_Users"
}
$Users = Import-Csv -Path "C:\LabScripts\NewUsers.csv"

$null = Get-ADOrganizationalUnit -Identity $OU
foreach ($Group in $Groups.Values) {
    $null = Get-ADGroup -Identity $Group
}

foreach ($User in $Users) {
    $Username = $User.Username.Trim()
    $Department = $User.Department.Trim()

    if ($Username -notmatch '^[a-z][a-z0-9._-]{0,19}$') {
        throw "Invalid username: $Username"
    }
    if (-not $Groups.ContainsKey($Department)) {
        throw "Unknown department: $Department"
    }
    if (Get-ADUser -Filter "SamAccountName -eq '$Username'") {
        Write-Host "SKIPPED: $Username already exists"
        continue
    }

    $GroupName = $Groups[$Department]
    $Password = Read-Host "Temporary password for $Username" -AsSecureString
    $FullName = "$($User.FirstName.Trim()) $($User.LastName.Trim())"
    $Parameters = @{
        Name = $FullName
        DisplayName = $FullName
        GivenName = $User.FirstName.Trim()
        Surname = $User.LastName.Trim()
        SamAccountName = $Username
        UserPrincipalName = "$Username@corp.sampath.test"
        Department = $Department
        Path = $OU
        AccountPassword = $Password
        Enabled = $true
        ChangePasswordAtLogon = $true
    }

    try {
        New-ADUser @Parameters
        Add-ADGroupMember -Identity $GroupName -Members $Username
        Write-Host "CREATED: $Username -> $GroupName"
    }
    catch {
        Write-Warning "FAILED: $Username - $($_.Exception.Message)"
    }
}
