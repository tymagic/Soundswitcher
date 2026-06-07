param(
    [string]$TargetPath,
    [string]$IconPath,
    [string]$ShortcutName = "Sound Switcher"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Desktop = [Environment]::GetFolderPath("Desktop")
$ShortcutPath = Join-Path $Desktop "$ShortcutName.lnk"

try {
    # 由于 QQPCMgr/腾讯电脑管家 HIPS 会拦截直接启动未签名 exe，
    # 通过 bat 启动器间接启动可绕过拦截
    $exeDir = Split-Path $TargetPath -Parent
    $batPath = Join-Path $exeDir "$ShortcutName.bat"
    $batContent = @"
@echo off
start "" "%~dp0$([System.IO.Path]::GetFileName($TargetPath))"
"@
    [System.IO.File]::WriteAllText($batPath, $batContent, [System.Text.Encoding]::ASCII)

    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $batPath
    $Shortcut.WorkingDirectory = $exeDir

    # 用 exe 自身图标（exe 已内置 icon）
    $Shortcut.IconLocation = "$TargetPath,0"

    $Shortcut.Description = "Sound Switcher - 一键切换音频设备组"
    $Shortcut.WindowStyle = 7
    $Shortcut.Save()

    Write-Output (@{ success = $true; path = $ShortcutPath; bat = $batPath } | ConvertTo-Json -Compress)
} catch {
    Write-Output (@{ success = $false; error = $_.Exception.Message } | ConvertTo-Json -Compress)
}