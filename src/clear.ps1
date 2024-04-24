$width = 120
$height = 30
$size = New-Object System.Management.Automation.Host.Size($width, $height)
$host.ui.rawui.windowsize = $size

# Проверка на администратора
$isAdmin = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544"
if (-not $isAdmin) {
    Start-Process powershell -ArgumentList " -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}


$excludedNames = @(
    "Default", 
    "Public", 
    "Общие", 
    "Default User", 
    "Пользователь по умолчанию", 
    "Administrator", 
    "Администратор", 
    "dezhur112", 
    "defaultuser", 
    "defaultuser0", 
    "admin112", 
    "user", 
    "secure", 
    "systemprofile", 
    "LocalService", 
    "NetworkService", 
    $env:USERNAME
).ToLower()
$usersFolder = "C:\Users"
$allUserFolders = Get-ChildItem -Path $usersFolder | Where-Object {
    $_.PSIsContainer -and $excludedNames -notcontains $_.Name.ToLower()
}


# Удаление профилей на диске
$logicalProcessors = (Get-CimInstance -ClassName Win32_Processor).NumberOfCores

Write-Host "УДАЛЕНИЕ ПОЛЬЗОВАТЕЛЬСКИХ ПАПОК"
$allUserFolders | ForEach-Object -Parallel {
    Write-Progress -Activity "Удаление папки профиля: $_" -Status "Удаление..."
    $path = $_.FullName
    try {
        Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
        Write-Host "--- $(Get-Date -Format 'HH:mm:ss') - Папка профиля $_ удалена." -ForegroundColor Green
    }
    catch {
        # Если возникла ошибка, пробую изменить разрешения
        $_.Exception | ForEach-Object {
            $failedItem = $_.TargetObject
            if ($failedItem) {
                # Попытка взять владение и изменить разрешения
                takeown.exe /F $failedItem /A /R /D Y
                icacls $failedItem /reset /T /C /Q
                icacls $failedItem /setowner "Administrators" /T /C /Q
                icacls $failedItem /grant "Administrators":(F) /T /C /Q
                # Попытка удалить ещё раз
                Remove-Item -Path $failedItem -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        # Проверка, удалена ли папка после изменения разрешений
        if (-not (Test-Path -Path $path)) {
            Write-Host "--- $(Get-Date -Format 'HH:mm:ss') - Папка профиля $_ удалена после изменения разрешений." -ForegroundColor Green
        }
        else {
            Write-Host "--- $(Get-Date -Format 'HH:mm:ss') - Не удалось удалить папку профиля $_ даже после изменения разрешений." -ForegroundColor Red
        }
    }
} -ThrottleLimit $logicalProcessors
Write-Progress -Activity "Пользовательские папки профилей удалены!" -Completed


# Удаление профилей в реестре
$profileListPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
$profileSubKeys = Get-ChildItem -Path $profileListPath

Write-Host "УДАЛЕНИЕ ПОЛЬЗОВАТЕЛЬСКИХ ПРОФИЛЕЙ ИЗ РЕЕСТРА"
foreach ($subKey in $profileSubKeys) {
    $profileImagePath = (Get-ItemProperty -Path $subKey.PSPath).ProfileImagePath
    $profileName = $profileImagePath -split '\\' | Select-Object -Last 1

    if ($profileName -notin $excludedNames) {
        Write-Progress -Activity "Удаление ветки профиля: $subKey.PSPath" -Status "Удаление..."
        Remove-Item -Path $subKey.PSPath -Force -Recurse
        Write-Host "--- Ветка профиля $profileName удалена." -ForegroundColor Green
    }
}
Write-Progress -Activity "Пользовательские ветки профилей удалены из реестра" -Completed

Write-Host "ГОТОВО."
pause