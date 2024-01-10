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

# Переменные
$installPath = "C:\Program Files\PowerShell"
$powershellCorePath = Join-Path -Path $installPath -ChildPath "7\pwsh.exe"
$minimumVersion = [System.Version]::new(7, 3, 10)
$scriptDirectory = $MyInvocation.MyCommand.Path | Split-Path
$scriptName = "clear.ps1"
$clearScriptPath = Join-Path -Path $scriptDirectory -ChildPath $scriptName



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

$currentVersion = Get-PowerShellCoreVersion

If ($currentVersion -lt $minimumVersion) {
    Write-Host "PowerShell Core is missing, or its version is lower $minimumVersion."
    Write-Progress -Activity "I'm starting the installation PowerShell Core $minimumVersion." -Status "Installation..."
    Install-PowerShellCore
    Write-Progress -Activity "Installation PowerShell Core $(Get-PowerShellCoreVersion) is complete!" -Completed
}
else {
    Write-Host "Installed version PowerShell Core $(Get-PowerShellCoreVersion)"
}

# Запуск скрипта очистки
if (Test-Path $clearScriptPath -PathType Leaf) {
    Write-Host "Running the cleaning script..." -ForegroundColor Green
    Start-Process -FilePath $powershellCorePath -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$clearScriptPath`"" -Verb RunAs
}
else {
    Write-Host "No script for cleaning was found. Put a script named $scriptName next to this script." -ForegroundColor Red
} 

pause