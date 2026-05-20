// ============================================
// Sound Switcher v2 - 渲染进程逻辑
// ============================================

// 状态
let devicesData = null;       // { outputs, inputs, groups, activeIndex }
let editMode = null;          // null | 'add' | { group object, index }
let editPickedOutput = null;
let editPickedInput = null;
let toastTimer = null;

// DOM
const $ = (id) => document.getElementById(id);
const elGroupList = $('group-list');
const elGroupCounter = $('group-counter');
const elEditPanel = $('edit-panel');
const elEditPanelTitle = $('edit-panel-title');
const elEditGroupName = $('edit-group-name');
const elEditOutputList = $('edit-output-list');
const elEditInputList = $('edit-input-list');
const elOutputDevices = $('output-devices');
const elInputDevices = $('input-devices');
const elBtnSwitch = $('btn-switch');
const elBtnSwitchText = $('btn-switch-text');
const elBtnRefresh = $('btn-refresh');
const elToast = $('toast');
const elHotkey = $('hotkey-display');
const elCollapseIcon = $('collapse-icon');

// 提示音（Web Audio API 合成，轻量无依赖）
let audioCtx = null;
function playNotificationSound() {
  try {
    if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    const now = audioCtx.currentTime;

    // 双音上升提示音：C5(523Hz) → E5(659Hz)，轻快悦耳
    [523, 659].forEach((freq, i) => {
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      osc.type = 'sine';
      osc.frequency.value = freq;
      gain.gain.setValueAtTime(0, now + i * 0.1);
      gain.gain.linearRampToValueAtTime(0.18, now + i * 0.1 + 0.04);
      gain.gain.linearRampToValueAtTime(0, now + i * 0.1 + 0.18);
      osc.connect(gain);
      gain.connect(audioCtx.destination);
      osc.start(now + i * 0.1);
      osc.stop(now + i * 0.1 + 0.2);
    });
  } catch (e) { /* 静默失败，不影响功能 */ }
}

// Toast
function toast(msg, type = '') {
  if (toastTimer) clearTimeout(toastTimer);
  elToast.textContent = msg;
  elToast.className = 'toast ' + type + ' show';
  toastTimer = setTimeout(() => elToast.classList.remove('show'), 2200);
  // 成功消息时播放提示音
  if (type === 'success') playNotificationSound();
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

// ============================================
// 设备组列表渲染
// ============================================
function renderGroupList() {
  if (!devicesData) return;

  const groups = devicesData.groups || [];
  const activeIdx = devicesData.activeIndex;

  elGroupCounter.textContent = groups.length + ' 组';

  if (groups.length === 0) {
    elGroupList.innerHTML = '<div class="group-empty">暂无设备组，点击 + 创建</div>';
    elBtnSwitchText.textContent = '切换下一组';
    return;
  }

  elGroupList.innerHTML = groups
    .map((g, i) => {
      const isActive = i === activeIdx;
      const outName = g.outputName || '未知';
      const inName = g.inputName || '未知';
      return `
        <div class="group-item ${isActive ? 'active' : ''}" data-index="${i}">
          <div class="group-indicator"></div>
          <div class="group-info" data-action="select">
            <div class="group-name">${escapeHtml(g.name)}</div>
            <div class="group-devices">🔊 ${escapeHtml(outName)} ｜ 🎤 ${escapeHtml(inName)}</div>
          </div>
          <div class="group-actions">
            <button class="group-btn" data-action="edit" data-index="${i}" title="编辑">✎</button>
            <button class="group-btn delete" data-action="delete" data-index="${i}" title="删除">✕</button>
          </div>
        </div>
      `;
    })
    .join('');

  // 绑定事件
  elGroupList.querySelectorAll('.group-item').forEach((item) => {
    item.addEventListener('click', (e) => {
      const idx = parseInt(item.dataset.index);
      const target = e.target;

      if (target.closest('[data-action="edit"]')) {
        openEditPanel(idx);
        return;
      }
      if (target.closest('[data-action="delete"]')) {
        deleteGroup(idx);
        return;
      }
      // 点击空白区域 = 选中并切换
      switchToGroup(idx);
    });
  });

  // 更新切换按钮文字
  if (activeIdx >= 0 && groups.length > 1) {
    const nextIdx = (activeIdx + 1) % groups.length;
    elBtnSwitchText.textContent = '切换到: ' + groups[nextIdx].name;
  } else if (groups.length === 1) {
    elBtnSwitchText.textContent = '切换: ' + groups[0].name;
  } else {
    elBtnSwitchText.textContent = '切换下一组';
  }
}

// ============================================
// 设备列表渲染（底部折叠区）
// ============================================
function renderDeviceLists() {
  if (!devicesData) return;

  const outputs = devicesData.outputs || [];
  const inputs = devicesData.inputs || [];

  elOutputDevices.innerHTML = outputs.length === 0
    ? '<div class="device-item placeholder">未检测到</div>'
    : outputs.map(d => `
      <div class="device-item" data-id="${d.id}">
        <div class="device-radio"></div>
        <div class="device-info">
          <div class="device-name">${escapeHtml(d.name)}</div>
        </div>
        ${d.isDefault ? '<span class="device-badge">默认</span>' : ''}
      </div>
    `).join('');

  elInputDevices.innerHTML = inputs.length === 0
    ? '<div class="device-item placeholder">未检测到</div>'
    : inputs.map(d => `
      <div class="device-item" data-id="${d.id}">
        <div class="device-radio"></div>
        <div class="device-info">
          <div class="device-name">${escapeHtml(d.name)}</div>
        </div>
        ${d.isDefault ? '<span class="device-badge">默认</span>' : ''}
      </div>
    `).join('');
}

// ============================================
// 编辑面板（添加/修改设备组）
// ============================================
function openEditPanel(groupIndex = null) {
  if (!devicesData) return;

  if (groupIndex !== null && devicesData.groups[groupIndex]) {
    // 编辑模式
    const g = devicesData.groups[groupIndex];
    editMode = { index: groupIndex, oldName: g.name };
    elEditPanelTitle.textContent = '编辑设备组';
    elEditGroupName.value = g.name;
    editPickedOutput = g.outputDeviceId;
    editPickedInput = g.inputDeviceId;
  } else {
    // 添加模式
    editMode = 'add';
    elEditPanelTitle.textContent = '添加设备组';
    elEditGroupName.value = '';
    // 默认选中当前系统默认设备
    const defOut = (devicesData.outputs || []).find(d => d.isDefault);
    const defIn = (devicesData.inputs || []).find(d => d.isDefault);
    editPickedOutput = defOut ? defOut.id : null;
    editPickedInput = defIn ? defIn.id : null;
  }

  renderEditDeviceLists();
  elEditPanel.style.display = 'block';
  elEditPanel.scrollIntoView({ behavior: 'smooth' });
}

function closeEditPanel() {
  editMode = null;
  editPickedOutput = null;
  editPickedInput = null;
  elEditPanel.style.display = 'none';
}

function renderEditDeviceLists() {
  const outputs = devicesData.outputs || [];
  const inputs = devicesData.inputs || [];

  elEditOutputList.innerHTML = outputs.map(d => `
    <div class="edit-device-item ${d.id === editPickedOutput ? 'picked' : ''}" data-id="${d.id}">
      <div class="edit-device-dot"></div>
      <span>${escapeHtml(d.name)}</span>
    </div>
  `).join('');

  elEditInputList.innerHTML = inputs.map(d => `
    <div class="edit-device-item ${d.id === editPickedInput ? 'picked' : ''}" data-id="${d.id}">
      <div class="edit-device-dot"></div>
      <span>${escapeHtml(d.name)}</span>
    </div>
  `).join('');

  // 点击选择
  elEditOutputList.querySelectorAll('.edit-device-item').forEach(item => {
    item.addEventListener('click', () => {
      editPickedOutput = item.dataset.id;
      renderEditDeviceLists();
    });
  });
  elEditInputList.querySelectorAll('.edit-device-item').forEach(item => {
    item.addEventListener('click', () => {
      editPickedInput = item.dataset.id;
      renderEditDeviceLists();
    });
  });
}

async function saveGroup() {
  const name = elEditGroupName.value.trim();
  if (!name) { toast('请输入组名称', 'error'); return; }
  if (!editPickedOutput) { toast('请选择输出设备', 'error'); return; }
  if (!editPickedInput) { toast('请选择输入设备', 'error'); return; }

  try {
    let result;
    if (editMode === 'add') {
      result = await window.electronAPI.saveGroup(name, editPickedOutput, editPickedInput);
    } else if (editMode && editMode.oldName) {
      result = await window.electronAPI.updateGroup(
        editMode.oldName, name, editPickedOutput, editPickedInput
      );
    }
    if (result && result.success) {
      toast('✅ 设备组已保存', 'success');
      closeEditPanel();
      await refreshAll();
    }
  } catch (err) {
    toast('保存失败: ' + err.message, 'error');
  }
}

async function deleteGroup(index) {
  if (!devicesData || !devicesData.groups[index]) return;
  const g = devicesData.groups[index];
  if (!confirm('确定要删除设备组 "' + g.name + '" 吗？')) return;

  try {
    const result = await window.electronAPI.deleteGroup(g.name);
    if (result && result.success) {
      toast('✅ 已删除', 'success');
      await refreshAll();
    }
  } catch (err) {
    toast('删除失败', 'error');
  }
}

// ============================================
// 切换设备组
// ============================================
async function switchToGroup(index) {
  elBtnSwitch.classList.add('switching');
  try {
    const result = await window.electronAPI.switchToGroup(index);
    if (result && result.success) {
      toast('✅ ' + (result.groupName || '已切换'), 'success');
    } else {
      toast('❌ ' + (result ? result.error : '切换失败'), 'error');
    }
  } catch (err) {
    toast('❌ 切换失败', 'error');
  } finally {
    setTimeout(() => elBtnSwitch.classList.remove('switching'), 600);
    setTimeout(refreshAll, 400);
  }
}

async function quickSwitch() {
  elBtnSwitch.classList.add('switching');
  try {
    const result = await window.electronAPI.switchDevices();
    if (result && result.success) {
      const g = devicesData.groups[result.groupIndex];
      toast('✅ ' + (g ? g.name : '下一组'), 'success');
    } else {
      toast('⚠️ ' + (result ? result.error : '请先创建设备组'), 'error');
    }
  } catch (err) {
    toast('❌ 切换失败', 'error');
  } finally {
    setTimeout(() => elBtnSwitch.classList.remove('switching'), 600);
    setTimeout(refreshAll, 400);
  }
}

// ============================================
// 数据刷新
// ============================================
async function refreshAll() {
  try {
    const data = await window.electronAPI.getDevices();
    if (data && data.success) {
      devicesData = data;
      renderGroupList();
      renderDeviceLists();
    }
  } catch (err) {
    toast('加载失败', 'error');
  }
}

// ============================================
// 事件绑定
// ============================================
$('btn-add-group').addEventListener('click', () => openEditPanel(null));
$('btn-save-group').addEventListener('click', saveGroup);
$('btn-cancel-edit').addEventListener('click', closeEditPanel);
$('btn-close-panel').addEventListener('click', closeEditPanel);
$('btn-switch').addEventListener('click', quickSwitch);
$('btn-refresh').addEventListener('click', refreshAll);
$('btn-shortcut').addEventListener('click', async () => {
  try {
    const result = await window.electronAPI.createShortcut();
    if (result && result.success) {
      toast('✅ 桌面快捷方式已创建', 'success');
    } else {
      toast('❌ 创建失败', 'error');
    }
  } catch (err) {
    toast('❌ 创建失败', 'error');
  }
});
$('btn-close').addEventListener('click', () => window.electronAPI.closeWindow());
$('btn-minimize').addEventListener('click', () => window.electronAPI.minimizeWindow());

// 折叠面板
$('toggle-devices').addEventListener('click', () => {
  const body = $('device-body');
  const icon = $('collapse-icon');
  body.classList.toggle('collapsed');
  icon.classList.toggle('open');
});

// 主进程事件
window.electronAPI.onDevicesUpdated((data) => {
  if (data && data.success) {
    devicesData = data;
    renderGroupList();
    renderDeviceLists();
    if (editMode) renderEditDeviceLists();
  }
});

window.electronAPI.onDeviceSwitched((result) => {
  if (result && result.success) {
    toast('✅ ' + (result.groupName || '已切换'), 'success');
  }
});

window.electronAPI.onSwitchError((error) => {
  toast('❌ ' + error, 'error');
});

window.electronAPI.onDevicesError((error) => {
  toast('⚠️ ' + error, 'error');
});

// F5 刷新
document.addEventListener('keydown', (e) => {
  if (e.key === 'F5') { e.preventDefault(); refreshAll(); }
});

// ============================================
// 初始化
// ============================================
async function init() {
  try {
    const hotkey = await window.electronAPI.getHotkey();
    const keys = hotkey.split('+');
    elHotkey.innerHTML = keys.map(k => `<kbd>${k}</kbd>`).join('<span>+</span>');
  } catch (e) { /* default */ }
  refreshAll();
}

document.addEventListener('DOMContentLoaded', init);
