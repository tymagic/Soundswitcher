# Sound Switcher - Audio Device Manager v2
# 支持多设备组管理 + UTF-8 编码修复
param(
    [string]$Action = "list",
    [string]$ProfileName = "",
    [string]$OutputDeviceId = "",
    [string]$InputDeviceId = "",
    [int]$ProfileIndex = -1,
    [string]$DeleteProfile = "",
    [string]$ParamsJson = ""   # 当包含中文时，用 JSON 文件传参
)

# ====== 强制 UTF-8 输出（修复中文乱码）======
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 如果通过 JSON 文件传参，读取并覆盖参数
if ($ParamsJson -and (Test-Path $ParamsJson)) {
    try {
        $jsonParams = Get-Content $ParamsJson -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($jsonParams.ProfileName)     { $ProfileName     = $jsonParams.ProfileName }
        if ($jsonParams.OutputDeviceId)  { $OutputDeviceId  = $jsonParams.OutputDeviceId }
        if ($jsonParams.InputDeviceId)   { $InputDeviceId   = $jsonParams.InputDeviceId }
        if ($jsonParams.ProfileIndex)    { $ProfileIndex    = $jsonParams.ProfileIndex }
        if ($jsonParams.DeleteProfile)   { $DeleteProfile   = $jsonParams.DeleteProfile }
        if ($jsonParams.NewProfileName)  { $NewProfileName  = $jsonParams.NewProfileName }
        # 清理
        Remove-Item $ParamsJson -Force -ErrorAction SilentlyContinue
    } catch { }
}

# Compile and load the C# audio API wrapper
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$CSPath = Join-Path $ScriptDir "AudioAPI.cs"

# 如果 CSPath 不存在（从其他路径调用时），尝试从 app.asar.unpacked 查找
if (-not (Test-Path $CSPath)) {
    $resourceDir = Join-Path $env:ProgramFiles "Sound Switcher\resources\app.asar.unpacked\scripts"
    if (Test-Path (Join-Path $resourceDir "AudioAPI.cs")) {
        $CSPath = Join-Path $resourceDir "AudioAPI.cs"
    }
}

try {
    Add-Type -Path $CSPath -ErrorAction Stop
} catch {
    $errorJson = @{
        success = $false
        error   = "Failed to compile AudioAPI"
    } | ConvertTo-Json -Compress
    Write-Output $errorJson
    exit 1
}

# ====== 配置路径 ======
$ConfigDir = "$env:APPDATA\SoundSwitcher"
if (-not (Test-Path $ConfigDir)) {
    New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
}
$ConfigPath = "$ConfigDir\profiles.json"

# ====== 配置文件读写 ======
function Load-Profiles {
    if (Test-Path $ConfigPath) {
        try {
            $content = Get-Content $ConfigPath -Raw -Encoding UTF8
            if ($content) { return $content | ConvertFrom-Json }
        } catch { }
    }
    return @{ activeIndex = -1; groups = @() }
}

function Save-Profiles($profiles) {
    $profiles | ConvertTo-Json -Depth 5 | Set-Content -Path $ConfigPath -Encoding UTF8
}

# ====== 获取设备名（通过 ID） ======
function Get-DeviceNameById($deviceId, $flow) {
    try {
        $devices = [SoundSwitcher.AudioDeviceManager]::GetDevices($flow)
        foreach ($d in $devices) {
            if ($d.Id -eq $deviceId) { return $d.Name }
        }
    } catch { }
    return "Unknown"
}

# ====== 动作: list - 列出所有设备 + 已保存的组 ======
function Get-AllDevices {
    $renderDevices = [SoundSwitcher.AudioDeviceManager]::GetDevices([SoundSwitcher.EDataFlow]::eRender)
    $captureDevices = [SoundSwitcher.AudioDeviceManager]::GetDevices([SoundSwitcher.EDataFlow]::eCapture)

    $renderList = @()
    foreach ($d in $renderDevices) {
        $renderList += @{ id = $d.Id; name = $d.Name; type = $d.Type; isDefault = $d.IsDefault }
    }

    $captureList = @()
    foreach ($d in $captureDevices) {
        $captureList += @{ id = $d.Id; name = $d.Name; type = $d.Type; isDefault = $d.IsDefault }
    }

    $profiles = Load-Profiles
    $groups = @()
    if ($profiles.groups) {
        foreach ($g in $profiles.groups) {
            $groups += @{
                name           = $g.name
                outputDeviceId = $g.outputDeviceId
                inputDeviceId  = $g.inputDeviceId
                outputName     = if ($g.outputName) { $g.outputName } else { Get-DeviceNameById $g.outputDeviceId ([SoundSwitcher.EDataFlow]::eRender) }
                inputName      = if ($g.inputName) { $g.inputName } else { Get-DeviceNameById $g.inputDeviceId ([SoundSwitcher.EDataFlow]::eCapture) }
            }
        }
    }

    @{
        success      = $true
        outputs      = $renderList
        inputs       = $captureList
        groups       = $groups
        activeIndex  = $profiles.activeIndex
    } | ConvertTo-Json -Compress -Depth 5
}

# ====== 动作: switch - 循环切换到下一个设备组 ======
function Invoke-SwitchDevices {
    $profiles = Load-Profiles
    $groups = $profiles.groups
    if (-not $groups -or $groups.Count -eq 0) {
        @{ success = $false; error = "No device groups configured" } | ConvertTo-Json -Compress
        return
    }

    # 计算下一个组索引（循环）
    $nextIndex = 0
    if ($profiles.activeIndex -ge 0 -and $profiles.activeIndex -lt $groups.Count) {
        $nextIndex = ($profiles.activeIndex + 1) % $groups.Count
    }

    $group = $groups[$nextIndex]
    $outId = $group.outputDeviceId
    $inId  = $group.inputDeviceId

    # 执行切换
    [SoundSwitcher.AudioDeviceManager]::SetDefaultEndpoint($outId, [SoundSwitcher.ERole]::eConsole) | Out-Null
    [SoundSwitcher.AudioDeviceManager]::SetDefaultEndpoint($inId, [SoundSwitcher.ERole]::eConsole) | Out-Null
    [SoundSwitcher.AudioDeviceManager]::SetDefaultEndpoint($outId, [SoundSwitcher.ERole]::eCommunications) | Out-Null
    [SoundSwitcher.AudioDeviceManager]::SetDefaultEndpoint($inId, [SoundSwitcher.ERole]::eCommunications) | Out-Null

    # 更新 activeIndex
    $profiles.activeIndex = $nextIndex
    Save-Profiles $profiles

    # 获取切换后设备名
    $newOut = [SoundSwitcher.AudioDeviceManager]::GetDefaultDevice([SoundSwitcher.EDataFlow]::eRender)
    $newIn  = [SoundSwitcher.AudioDeviceManager]::GetDefaultDevice([SoundSwitcher.EDataFlow]::eCapture)

    @{
        success         = $true
        groupName       = $group.name
        groupIndex      = $nextIndex
        totalGroups     = $groups.Count
        outputChangedTo = if ($newOut) { $newOut.Name } else { "" }
        inputChangedTo  = if ($newIn)  { $newIn.Name } else { "" }
    } | ConvertTo-Json -Compress
}

# ====== 动作: switch-to - 切换到指定索引的组 ======
function Invoke-SwitchToGroup($index) {
    $profiles = Load-Profiles
    if (-not $profiles.groups -or $index -ge $profiles.groups.Count) {
        @{ success = $false; error = "Invalid group index" } | ConvertTo-Json -Compress
        return
    }

    $group = $profiles.groups[$index]

    [SoundSwitcher.AudioDeviceManager]::SetDefaultEndpoint($group.outputDeviceId, [SoundSwitcher.ERole]::eConsole) | Out-Null
    [SoundSwitcher.AudioDeviceManager]::SetDefaultEndpoint($group.inputDeviceId, [SoundSwitcher.ERole]::eConsole) | Out-Null
    [SoundSwitcher.AudioDeviceManager]::SetDefaultEndpoint($group.outputDeviceId, [SoundSwitcher.ERole]::eCommunications) | Out-Null
    [SoundSwitcher.AudioDeviceManager]::SetDefaultEndpoint($group.inputDeviceId, [SoundSwitcher.ERole]::eCommunications) | Out-Null

    $profiles.activeIndex = $index
    Save-Profiles $profiles

    $newOut = [SoundSwitcher.AudioDeviceManager]::GetDefaultDevice([SoundSwitcher.EDataFlow]::eRender)
    $newIn  = [SoundSwitcher.AudioDeviceManager]::GetDefaultDevice([SoundSwitcher.EDataFlow]::eCapture)

    @{
        success         = $true
        groupName       = $group.name
        groupIndex      = $index
        outputChangedTo = if ($newOut) { $newOut.Name } else { "" }
        inputChangedTo  = if ($newIn)  { $newIn.Name } else { "" }
    } | ConvertTo-Json -Compress
}

# ====== 动作: save-group - 保存一个新的设备组 ======
function Save-DeviceGroup {
    param([string]$Name, [string]$OutId, [string]$InId)
    if (-not $Name) { $Name = "Group $(Get-Date -Format 'HHmmss')" }

    $profiles = Load-Profiles
    if (-not $profiles.groups) {
        $profiles | Add-Member -NotePropertyName groups -NotePropertyValue @() -Force
    }

    # 转换为可修改的数组（PSObject[] -> ArrayList 避免引用问题）
    $groups = New-Object System.Collections.ArrayList
    foreach ($g in $profiles.groups) { [void]$groups.Add($g) }

    $newGroup = @{
        name           = $Name
        outputDeviceId = $OutId
        inputDeviceId  = $InId
        outputName     = Get-DeviceNameById $OutId ([SoundSwitcher.EDataFlow]::eRender)
        inputName      = Get-DeviceNameById $InId ([SoundSwitcher.EDataFlow]::eCapture)
    }
    [void]$groups.Add($newGroup)
    $profiles.groups = $groups.ToArray()

    if ($profiles.activeIndex -lt 0) { $profiles.activeIndex = 0 }
    Save-Profiles $profiles

    @{ success = $true; groups = $profiles.groups; activeIndex = $profiles.activeIndex } | ConvertTo-Json -Compress -Depth 5
}

# ====== 动作: delete-group - 删除设备组 ======
function Remove-DeviceGroup {
    param([string]$Name)
    $profiles = Load-Profiles
    if (-not $profiles.groups) {
        @{ success = $false; error = "No groups" } | ConvertTo-Json -Compress
        return
    }

    $groups = New-Object System.Collections.ArrayList
    foreach ($g in $profiles.groups) { [void]$groups.Add($g) }

    $index = -1
    for ($i = 0; $i -lt $groups.Count; $i++) {
        if ($groups[$i].name -eq $Name) { $index = $i; break }
    }
    if ($index -ge 0) {
        $groups.RemoveAt($index)
        $profiles.groups = $groups.ToArray()
        if ($profiles.activeIndex -ge $groups.Count) { $profiles.activeIndex = $groups.Count - 1 }
        Save-Profiles $profiles
    }

    @{ success = $true; groups = $profiles.groups; activeIndex = $profiles.activeIndex } | ConvertTo-Json -Compress -Depth 5
}

# ====== 动作: update-group - 更新设备组 ======
function Update-DeviceGroup {
    param([string]$OldName, [string]$NewName, [string]$OutId, [string]$InId)
    $profiles = Load-Profiles
    if (-not $profiles.groups) {
        @{ success = $false; error = "No groups" } | ConvertTo-Json -Compress
        return
    }
    $groups = New-Object System.Collections.ArrayList
    foreach ($g in $profiles.groups) { [void]$groups.Add($g) }

    for ($i = 0; $i -lt $groups.Count; $i++) {
        if ($groups[$i].name -eq $OldName) {
            if ($NewName) { $groups[$i].name = $NewName }
            if ($OutId) {
                $groups[$i].outputDeviceId = $OutId
                $groups[$i].outputName = Get-DeviceNameById $OutId ([SoundSwitcher.EDataFlow]::eRender)
            }
            if ($InId) {
                $groups[$i].inputDeviceId = $InId
                $groups[$i].inputName = Get-DeviceNameById $InId ([SoundSwitcher.EDataFlow]::eCapture)
            }
            break
        }
    }
    $profiles.groups = $groups.ToArray()
    Save-Profiles $profiles
    @{ success = $true; groups = $profiles.groups; activeIndex = $profiles.activeIndex } | ConvertTo-Json -Compress -Depth 5
}

# ====== 主入口 ======
switch ($Action) {
    "list" {
        Get-AllDevices
    }
    "switch" {
        Invoke-SwitchDevices
    }
    "switch-to" {
        Invoke-SwitchToGroup $ProfileIndex
    }
    "save-group" {
        Save-DeviceGroup -Name $ProfileName -OutId $OutputDeviceId -InId $InputDeviceId
    }
    "delete-group" {
        Remove-DeviceGroup -Name $DeleteProfile
    }
    "update-group" {
        $newName = if ($NewProfileName) { $NewProfileName } else { $ProfileName }
        Update-DeviceGroup -OldName $DeleteProfile -NewName $newName -OutId $OutputDeviceId -InId $InputDeviceId
    }
    default {
        @{ success = $false; error = "Unknown action: $Action" } | ConvertTo-Json -Compress
    }
}
