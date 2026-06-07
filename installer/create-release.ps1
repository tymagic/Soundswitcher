[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=== GitHub Release Upload Helper ==="
Write-Host ""
Write-Host "由于当前环境无法直接使用 gh CLI 或 git push 上传大文件，"
Write-Host "请手动在浏览器中完成以下步骤："
Write-Host ""
Write-Host "1. 打开: https://github.com/tymagic/Soundswitcher/releases/new"
Write-Host "2. Tag: v1.0.0"
Write-Host "3. Release title: Sound Switcher v1.0.0"
Write-Host "4. 拖入以下两个文件："
Write-Host ""
$zip = Get-Item "c:\Users\Administrator\CodeBuddy\20260520131421\sound-switcher\Sound-Switcher-v1.0.0-win-x64.zip" -ErrorAction SilentlyContinue
$setup = Get-Item "c:\Users\Administrator\CodeBuddy\20260520131421\sound-switcher\Sound-Switcher-Setup-v1.0.0.exe" -ErrorAction SilentlyContinue

if ($zip) {
    Write-Host "   ✅ Sound-Switcher-v1.0.0-win-x64.zip ($([math]::Round($zip.Length/1MB,1)) MB)"
    Write-Host "      路径: $($zip.FullName)"
}
if ($setup) {
    Write-Host "   ✅ Sound-Switcher-Setup-v1.0.0.exe ($([math]::Round($setup.Length/1MB,1)) MB)"
    Write-Host "      路径: $($setup.FullName)"
}
Write-Host ""
Write-Host "5. 点击 Publish Release"
Write-Host ""
Write-Host "Release 发布后，README 中的下载链接将自动生效。"