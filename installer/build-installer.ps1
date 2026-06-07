$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.IO.Compression.FileSystem

$appDir = Split-Path $PSScriptRoot -Parent
$srcDir = "$appDir\release\win-unpacked"
$outDir = "$appDir"
$outFile = "$outDir\Sound-Switcher-Setup-v1.0.0.exe"

Write-Host "=== Building self-extracting installer ==="

# Step 1: Create payload zip
$zipFile = "$env:TEMP\ss_payload.zip"
if (Test-Path $zipFile) { Remove-Item $zipFile -Force }
Write-Host "Creating payload zip (104 MB)..."
[System.IO.Compression.ZipFile]::CreateFromDirectory($srcDir, $zipFile, [System.IO.Compression.CompressionLevel]::Optimal, $false)
Write-Host "Zip done."

# Step 2: Create self-extracting exe by prepending batch to zip
$batHeader = @'
@echo off
title Sound Switcher v1.0.0 Setup
echo.
echo   ======================================
echo       Sound Switcher v1.0.0 Setup
echo   ======================================
echo.
echo   Installing to C:\Program Files\SoundSwitcher...
echo.

>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

taskkill /f /im "Sound Switcher.exe" 2>nul
rmdir /s /q "C:\Program Files\SoundSwitcher" 2>nul

echo Extracting files...
powershell -NoProfile -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; $src='%~f0'; $dst='C:\Program Files\SoundSwitcher'; $fs=[System.IO.File]::OpenRead($src); $fs.Seek(__ZIPSTART__, [System.IO.SeekOrigin]::Begin); $zip=[System.IO.Compression.ZipArchive]::new($fs); [System.IO.Compression.ZipFileExtensions]::ExtractToDirectory($zip, $dst); $zip.Dispose(); $fs.Dispose()"

echo Creating shortcuts...
powershell -NoProfile -Command "$ws=New-Object -ComObject WScript.Shell; $desk=[Environment]::GetFolderPath('Desktop'); $s=$ws.CreateShortcut($desk+'\Sound Switcher.lnk'); $s.TargetPath='C:\Program Files\SoundSwitcher\Sound Switcher.exe'; $s.WorkingDirectory='C:\Program Files\SoundSwitcher'; $s.IconLocation='C:\Program Files\SoundSwitcher\Sound Switcher.exe,0'; $s.Description='Sound Switcher - 一键切换音频设备组'; $s.Save(); $sm=$ws.SpecialFolders('Programs')+'\Sound Switcher'; New-Item -ItemType Directory -Path $sm -Force | Out-Null; $s2=$ws.CreateShortcut($sm+'\Sound Switcher.lnk'); $s2.TargetPath='C:\Program Files\SoundSwitcher\Sound Switcher.exe'; $s2.WorkingDirectory='C:\Program Files\SoundSwitcher'; $s2.IconLocation='C:\Program Files\SoundSwitcher\Sound Switcher.exe,0'; $s2.Save(); $uninstBat='C:\Program Files\SoundSwitcher\uninstall.bat'; '@echo off'|Out-File $uninstBat -Encoding ASCII; 'taskkill /f /im Sound Switcher.exe 2>nul'|Out-File $uninstBat -Encoding ASCII -Append; 'del ""%DESKTOP%\Sound Switcher.lnk"" 2>nul'|Out-File $uninstBat -Encoding ASCII -Append; 'rmdir /s /q ""C:\Program Files\SoundSwitcher"" 2>nul'|Out-File $uninstBat -Encoding ASCII -Append; 'rmdir /s /q ""%APPDATA%\Microsoft\Windows\Start Menu\Programs\Sound Switcher"" 2>nul'|Out-File $uninstBat -Encoding ASCII -Append; 'echo Done. Press any key...'|Out-File $uninstBat -Encoding ASCII -Append; 'pause>nul'|Out-File $uninstBat -Encoding ASCII -Append; $s3=$ws.CreateShortcut($sm+'\Uninstall Sound Switcher.lnk'); $s3.TargetPath=$uninstBat; $s3.WorkingDirectory='C:\Program Files\SoundSwitcher'; $s3.Save()"

echo.
echo   ======================================
echo       Installation Complete!
echo   ======================================
echo.
pause
exit /b
'@

# Replace __ZIPSTART__ with the actual byte position where zip data begins
$batHeaderWithPlaceholder = $batHeader
# First, write bat header to get its byte length
$batBytes = [System.Text.Encoding]::ASCII.GetBytes($batHeaderWithPlaceholder)
# Find and replace placeholder with actual position
$zipStartPos = $batBytes.Length
$batContent = $batHeaderWithPlaceholder.Replace('__ZIPSTART__', $zipStartPos.ToString())
$batBytes = [System.Text.Encoding]::ASCII.GetBytes($batContent)

# Combine bat + zip
Write-Host "Combining bat + zip into self-extracting exe..."
$zipBytes = [System.IO.File]::ReadAllBytes($zipFile)
$allBytes = $batBytes + $zipBytes
[System.IO.File]::WriteAllBytes($outFile, $allBytes)

$size = [math]::Round($allBytes.Length / 1MB, 1)
Write-Host "`nSUCCESS! Installer: $outFile ($size MB)"
Write-Host "`nTo use: Double-click Sound-Switcher-Setup-v1.0.0.exe"

# Cleanup
Remove-Item $zipFile -Force -ErrorAction SilentlyContinue
Write-Host "Done!"