const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  // 设备数据
  getDevices: () => ipcRenderer.invoke('get-devices'),

  // 一键切换（循环组）
  switchDevices: () => ipcRenderer.invoke('switch-devices'),

  // 切换到指定组
  switchToGroup: (index) => ipcRenderer.invoke('switch-to-group', index),

  // 设备组管理
  saveGroup: (name, outputDeviceId, inputDeviceId) =>
    ipcRenderer.invoke('save-group', name, outputDeviceId, inputDeviceId),
  deleteGroup: (name) => ipcRenderer.invoke('delete-group', name),
  updateGroup: (oldName, newName, outputDeviceId, inputDeviceId) =>
    ipcRenderer.invoke('update-group', oldName, newName, outputDeviceId, inputDeviceId),

  // 快捷键
  getHotkey: () => ipcRenderer.invoke('get-hotkey'),

  // 窗口控制
  closeWindow: () => ipcRenderer.invoke('close-window'),
  minimizeWindow: () => ipcRenderer.invoke('minimize-window'),

  // 桌面快捷方式
  createShortcut: () => ipcRenderer.invoke('create-shortcut'),

  // 事件监听
  onDevicesUpdated: (callback) => {
    ipcRenderer.on('devices-updated', (_event, devices) => callback(devices));
  },
  onDeviceSwitched: (callback) => {
    ipcRenderer.on('device-switched', (_event, result) => callback(result));
  },
  onSwitchError: (callback) => {
    ipcRenderer.on('switch-error', (_event, error) => callback(error));
  },
  onDevicesError: (callback) => {
    ipcRenderer.on('devices-error', (_event, error) => callback(error));
  },
  removeAllListeners: (channel) => {
    ipcRenderer.removeAllListeners(channel);
  },
});
