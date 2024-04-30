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
        $failedPath = $path
        if (Test-Path -Path $failedPath) {
            $items = Get-ChildItem -Path $failedPath -Recurse -Force
            foreach ($item in $items) {
                try {
                    # Попытка удалить элемент
                    Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                }
                catch {
                    # Если удалить не удалось, берём владение и изменяем разрешения
                    takeown.exe /F $item.FullName /A /R /D Y 2>&1 > $null
                    icacls $item.FullName /reset /T /C /Q 2>&1 > $null
                    icacls $item.FullName /setowner "$env:USERNAME" /T /C /Q 2>&1 > $null
                    icacls $item.FullName /grant "$($env:USERNAME):(F)" /T /C /Q 2>&1 > $null
                    # Попытка удалить элемент ещё раз
                    Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
            # После попытки удаления всех элементов, проверяем, можно ли удалить саму папку
            try {
                Remove-Item -Path $failedPath -Recurse -Force -ErrorAction Stop
                Write-Host "--- $(Get-Date -Format 'HH:mm:ss') - Папка профиля $failedPath удалена после обработки файлов." -ForegroundColor Green
            }
            catch {
                Write-Host "--- $(Get-Date -Format 'HH:mm:ss') - Не удалось удалить папку профиля $failedPath после обработки файлов." -ForegroundColor Red
            }
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