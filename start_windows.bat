@echo off
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Demande de privileges administrateur...
    powershell Start-Process '%0' -Verb RunAs
    exit /b
)

set "INSTALL_DIR=%ProgramFiles%\URLMonitor"
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

:: Copie du fichier config.yml
copy /Y "config.yml" "%INSTALL_DIR%\config.yml"

powershell -Command "$script = @'
`$LogFile = 'C:\Logs\url_monitor.log'
if (-not (Test-Path 'C:\Logs')) { New-Item -ItemType Directory -Path 'C:\Logs' }

function Get-URLFromConfig {
    `$configPath = Join-Path `$PSScriptRoot 'config.yml'
    if (Test-Path `$configPath) {
        `$content = Get-Content `$configPath -Raw
        if (`$content -match 'url=(.*)') {
            return `$matches[1].Trim('\"')
        }
    }
    return `$null
}

while(`$true) {
    `$URL = Get-URLFromConfig
    if(`$URL) {
        try {
            `$response = Invoke-WebRequest -Uri `$URL -Method Head -UseBasicParsing
            `$statusCode = [int]`$response.StatusCode
            if(`$statusCode -ge 400) {
                New-BurntToastNotification -Text 'Erreur detectee!', ('Code HTTP: ' + `$statusCode + ' sur ' + `$URL)
                Add-Content `$LogFile ((Get-Date).ToString() + ' - Erreur ' + `$statusCode + ' detectee sur ' + `$URL)
            }
        } catch {
            `$statusCode = [int]`$_.Exception.Response.StatusCode
            New-BurntToastNotification -Text 'Erreur detectee!', ('Code HTTP: ' + `$statusCode + ' sur ' + `$URL)
            Add-Content `$LogFile ((Get-Date).ToString() + ' - Erreur ' + `$statusCode + ' detectee sur ' + `$URL)
        }
    } else {
        Add-Content `$LogFile ((Get-Date).ToString() + ' - URL non definie dans config.yml')
    }
    Start-Sleep -Seconds 600
}
'@ | Set-Content '%INSTALL_DIR%\monitor.ps1'"

powershell -Command "if (-not (Get-Module -ListAvailable -Name BurntToast)) { Install-Module -Name BurntToast -Force -Scope AllUsers }"

schtasks /Create /TN "URLMonitor" /TR "powershell -ExecutionPolicy Bypass -File \"%INSTALL_DIR%\monitor.ps1\"" /SC ONSTART /RU SYSTEM /F

start /B powershell -ExecutionPolicy Bypass -File "%INSTALL_DIR%\monitor.ps1"

echo Programme installe et demarre. Les logs sont dans C:\Logs\url_monitor.log
pause