$width = 120
$height = 30
$size = New-Object System.Management.Automation.Host.Size($width, $height)
$host.ui.rawui.windowsize = $size

$isAdmin = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544"
if (-not $isAdmin) {
    Start-Process powershell -ArgumentList " -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$excludedNames = @("Default", "Public", "Общие", "Default User", "Пользователь по умолчанию", "Administrator", "Администратор", "dezhur112", "defaultuser", "defaultuser0", "Admin112", "admin112", "User", "user", "Secure", "secure", "systemprofile", "LocalService", "NetworkService", $env:USERNAME)

$usersFolder = "C:\Users"

$allUserFolders = Get-ChildItem -Path $usersFolder | Where-Object { $_.PSIsContainer -and $excludedNames -notcontains $_.Name }

Write-Host "DELETING USER FOLDERS"
foreach ($userFolder in $allUserFolders) {
	Write-Progress -Activity "Deleting user folders: $userFolder" -Status "Deleting..."
	$takeown = "takeown.exe /F $($userFolder.FullName) /A /R /D Y"
	Invoke-Expression $takeown 2>&1 > $null
    	Remove-Item -Path $userFolder.FullName -Recurse -Force
	Write-Host "---Profile folder for $userFolder removed." -ForegroundColor Green
}
Write-Progress -Activity "Deleting user folders" -Completed

$profileListPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
$profileSubKeys = Get-ChildItem -Path $profileListPath

Write-Host "DELETING USER BRANCHES IN REGISTRY"
foreach ($subKey in $profileSubKeys) {
    $profileImagePath = (Get-ItemProperty -Path $subKey.PSPath).ProfileImagePath
    $profileName = $profileImagePath -split '\\' | Select-Object -Last 1

    if ($profileName -notin $excludedNames) {
	Write-Progress -Activity "Deleting user branches in registry: $subKey.PSPath" -Status "Deleting..."
        Remove-Item -Path $subKey.PSPath -Force -Recurse
        Write-Host "---Profile key for $profileName removed." -ForegroundColor Green
    }
}
Write-Progress -Activity "Deleting user branches in registry" -Completed

Write-Host "DONE."
pause
