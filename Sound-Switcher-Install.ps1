# Sound Switcher v1.0.0 安装脚本
# 用法: 右键此文件 -> "使用 PowerShell 运行" 或
#      以管理员身份打开 PowerShell，执行: .\Sound-Switcher-Install.ps1

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

# 检查管理员权限
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "需要管理员权限，正在请求..."
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

Write-Host "========================================"
Write-Host "  Sound Switcher v1.0.0 安装程序"
Write-Host "========================================"
Write-Host ""

$installDir = "C:\Program Files\SoundSwitcher"
$srcDir = Split-Path $PSCommandPath -Parent

# 停止正在运行的实例
Write-Host "停止正在运行的实例..."
Get-Process -Name "Sound*" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 1

# 创建安装目录
Write-Host "创建安装目录: $installDir"
if (Test-Path $installDir) {
    Remove-Item -Recurse -Force $installDir
}
New-Item -ItemType Directory -Path $installDir -Force | Out-Null

# 复制文件
Write-Host "复制文件..."
$srcRelease = Join-Path $srcDir "release\win-unpacked"
if (-not (Test-Path $srcRelease)) {
    Write-Host "错误: 找不到 release\win-unpacked 目录"
    Write-Host "请确保此脚本放在 sound-switcher 项目根目录"
    pause
    exit 1
}
Copy-Item "$srcRelease\*" $installDir -Recurse -Force

# 创建桌面快捷方式
Write-Host "创建桌面快捷方式..."
$ws = New-Object -ComObject WScript.Shell
$desk = [Environment]::GetFolderPath("Desktop")
$s = $ws.CreateShortcut(Join-Path $desk "Sound Switcher.lnk")
$s.TargetPath = Join-Path $installDir "Sound Switcher.exe"
$s.WorkingDirectory = $installDir
$s.IconLocation = "$($s.TargetPath),0"
$s.Description = "Sound Switcher - 一键切换音频设备组"
$s.Save()

# 创建开始菜单快捷方式
Write-Host "创建开始菜单快捷方式..."
$sm = Join-Path $ws.SpecialFolders("Programs") "Sound Switcher"
New-Item -ItemType Directory -Path $sm -Force | Out-Null
$s2 = $ws.CreateShortcut(Join-Path $sm "Sound Switcher.lnk")
$s2.TargetPath = Join-Path $installDir "Sound Switcher.exe"
$s2.WorkingDirectory = $installDir
$s2.IconLocation = "$($s2.TargetPath),0"
$s2.Save()

# 创建卸载脚本
Write-Host "创建卸载程序..."
$uninst = @'
@echo off
echo Uninstalling Sound Switcher...
taskkill /f /im "Sound Switcher.exe" 2>nul
del "%DESKTOP%\Sound Switcher.lnk" 2>nul
rmdir /s /q "C:\Program Files\SoundSwitcher" 2>nul
rmdir /s /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Sound Switcher" 2>nul
echo Done.
pause
'@
$uninst | Out-File (Join-Path $installDir "uninstall.bat") -Encoding ASCII

$s3 = $ws.CreateShortcut(Join-Path $sm "Uninstall Sound Switcher.lnk")
$s3.TargetPath = Join-Path $installDir "uninstall.bat"
$s3.WorkingDirectory = $installDir
$s3.Save()

# 写入注册表卸载信息
Write-Host "注册卸载信息..."
New-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\SoundSwitcher" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\SoundSwitcher" -Name "DisplayName" -Value "Sound Switcher"
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\SoundSwitcher" -Name "UninstallString" -Value "C:\Program Files\SoundSwitcher\uninstall.bat"
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\SoundSwitcher" -Name "DisplayIcon" -Value "C:\Program Files\SoundSwitcher\Sound Switcher.exe,0"
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\SoundSwitcher" -Name "DisplayVersion" -Value "1.0.0"
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\SoundSwitcher" -Name "Publisher" -Value "tymagic"
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\SoundSwitcher" -Name "NoModify" -Value 1 -Type DWord
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\SoundSwitcher" -Name "NoRepair" -Value 1 -Type DWord

Write-Host ""
Write-Host "========================================"
Write-Host "  安装完成！"
Write-Host "========================================"
Write-Host ""
Write-Host "桌面和开始菜单已创建快捷方式。"
Write-Host "卸载: 开始菜单 -> Sound Switcher -> Uninstall"
Write-Host ""
pause