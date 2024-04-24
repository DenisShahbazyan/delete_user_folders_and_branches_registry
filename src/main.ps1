$installPath = "C:\Program Files\PowerShell"
$powershellCorePath = Join-Path -Path $installPath -ChildPath "7\pwsh.exe"
$minimumVersion = [System.Version]::new(7, 3, 10)
$scriptDirectory = $MyInvocation.MyCommand.Path | Split-Path
$scriptName = "clear.ps1"
$clearScriptPath = Join-Path -Path $scriptDirectory -ChildPath $scriptName


function Start-Administrator {
    $isAdmin = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544"
    if (-not $isAdmin) {
        Start-Process powershell -ArgumentList " -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
}

# Установка PS Core 7.3.10
function Install-PowerShellCore {
    $installerUrl = "https://github.com/PowerShell/PowerShell/releases/download/v7.3.10/PowerShell-7.3.10-win-x64.msi"
    $installerPath = "$env:TEMP\PowerShellInstaller.msi"
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath
    Start-Process -Wait -FilePath msiexec.exe -ArgumentList "/i $installerPath /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1"
    [Environment]::SetEnvironmentVariable('Path', "$($env:Path);$installPath", [System.EnvironmentVariableTarget]::Machine)
    Remove-Item -Path $installerPath -Force
}

# Проверка версии PowerShell Core
function Get-PowerShellCoreVersion {
    if (-not (Test-Path $powershellCorePath -PathType Leaf)) {
        return $null
    }
    $versionInfo = Get-Item -LiteralPath $powershellCorePath | Get-ItemProperty | Select-Object -Property VersionInfo
    $version = $versionInfo.VersionInfo.ProductVersion.Split(' ')[0]
    $versionObject = [System.Version]$version
    return $versionObject
}

function Start-CheckPowerShellCore {
    $currentVersion = Get-PowerShellCoreVersion
    
    If ($currentVersion -lt $minimumVersion) {
        Write-Host "PowerShell Core отсутствует или его версия ниже $minimumVersion."
        Write-Progress -Activity "Запускаю установку PowerShell Core $minimumVersion." -Status "Установка..."
        Install-PowerShellCore
        Write-Progress -Activity "Установка PowerShell Core $(Get-PowerShellCoreVersion) завершена!" -Completed
    }
    else {
        Write-Host "Установленная версия PowerShell Core $(Get-PowerShellCoreVersion)"
    }
}

function Start-CleaningScript {
    if (Test-Path $clearScriptPath -PathType Leaf) {
        Write-Host "Запуск сценария очистки..." -ForegroundColor Green
        Start-Process -FilePath $powershellCorePath -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$clearScriptPath`"" -Verb RunAs
    }
    else {
        Write-Host "Скрипт для очистки не найден. Поместите скрипт с именем $scriptName рядом с этим скриптом." -ForegroundColor Red
    }     
}

Start-Administrator
Start-CheckPowerShellCore
Start-CleaningScript

pause