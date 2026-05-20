param(
    [string]$TargetPath,
    [string]$IconPath,
    [string]$ShortcutName = "Sound Switcher"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Desktop = [Environment]::GetFolderPath("Desktop")
$ShortcutPath = Join-Path $Desktop "$ShortcutName.lnk"

try {
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $TargetPath
    $Shortcut.WorkingDirectory = Split-Path $TargetPath -Parent

    # 用 exe 自身图标（exe 已内置 icon）
    $Shortcut.IconLocation = "$TargetPath,0"

    $Shortcut.Description = "Sound Switcher - 一键切换音频设备组"
    $Shortcut.Save()

    Write-Output (@{ success = $true; path = $ShortcutPath } | ConvertTo-Json -Compress)
} catch {
    Write-Output (@{ success = $false; error = $_.Exception.Message } | ConvertTo-Json -Compress)
}