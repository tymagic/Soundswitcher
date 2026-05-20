const { app, BrowserWindow, globalShortcut, Tray, Menu, ipcMain, nativeImage } = require('electron');
const path = require('path');
const fs = require('fs');
const os = require('os');
const { execFile } = require('child_process');

let mainWindow = null;
let tray = null;
let isQuitting = false;

// 快捷键配置
const HOTKEY = 'Ctrl+Shift+F12';

// 判断是否运行在 asar 打包环境中
const isAsar = __dirname.includes('app.asar');

// 获取应用根目录（兼容 asar 和开发模式）
function getAppRoot() {
  if (isAsar) {
    // 打包后: resources/app.asar -> resources/
    return path.join(process.resourcesPath, 'app.asar');
  }
  return __dirname;
}

// 获取脚本路径（scripts 在 asarUnpack 中，实际路径是 app.asar.unpacked）
function getScriptsDir() {
  if (isAsar) {
    return path.join(process.resourcesPath, 'app.asar.unpacked', 'scripts');
  }
  return path.join(__dirname, 'scripts');
}

function getPsPath(scriptName) {
  return path.join(getScriptsDir(), scriptName);
}

// 运行 PowerShell 脚本（修复中文乱码：-File + 单独参数避免编码问题）
function runPowerShell(scriptPath, args = []) {
  return new Promise((resolve, reject) => {
    const psArgs = [
      '-NoProfile',
      '-ExecutionPolicy', 'Bypass',
      '-File', scriptPath,
      ...args,
    ];
    execFile(
      'powershell.exe',
      psArgs,
      { encoding: 'buffer', maxBuffer: 2 * 1024 * 1024, windowsHide: true },
      (err, stdout, stderr) => {
        if (err) {
          console.error('PS Error:', err.message);
          reject(err);
          return;
        }
        if (stderr && stderr.length > 0) {
          const errStr = stderr.toString('utf8').trim();
          if (errStr) console.warn('PS Stderr:', errStr);
        }
        try {
          const text = stdout.toString('utf8').trim();
          // 跳过可能的 BOM
          const clean = text.replace(/^\uFEFF/, '');
          const result = JSON.parse(clean);
          resolve(result);
        } catch (e) {
          try {
            const text16 = stdout.toString('utf16le').trim();
            const clean16 = text16.replace(/^\uFEFF/, '');
            const result = JSON.parse(clean16);
            resolve(result);
          } catch (e2) {
            const rawUtf8 = stdout.toString('utf8').substring(0, 300);
            console.error('Parse Error. Raw:', rawUtf8);
            reject(new Error('Failed to parse PowerShell output: ' + rawUtf8));
          }
        }
      }
    );
  });
}

// 通过临时 JSON 文件传参（避免命令行编码问题影响中文）
async function runPowerShellWithJson(action, jsonParams) {
  const tmpFile = path.join(os.tmpdir(), `soundswitcher_${Date.now()}_${Math.random().toString(36).slice(2, 8)}.json`);
  const fullParams = { ...jsonParams };
  fs.writeFileSync(tmpFile, JSON.stringify(fullParams), 'utf8');

  const script = getPsPath('audio.ps1');
  const args = ['-Action', action, '-ParamsJson', tmpFile];

  // 如果有不需要中文的简单参数（如 index），也可以直接传
  return runPowerShell(script, args);
}

// 获取资源文件路径（assets 在 asar 内可正常读取，但图标需要文件系统路径）
function getAssetPath(fileName) {
  if (isAsar) {
    // 打包后尝试从 unpacked 目录读取
    const unpacked = path.join(process.resourcesPath, 'app.asar.unpacked', 'assets', fileName);
    if (fs.existsSync(unpacked)) return unpacked;
  }
  return path.join(__dirname, 'assets', fileName);
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 500,
    height: 720,
    resizable: false,
    frame: false,
    transparent: true,
    alwaysOnTop: false,
    skipTaskbar: false,
    icon: getAssetPath('icon.png'),
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  mainWindow.loadFile(path.join(__dirname, 'renderer', 'index.html'));

  mainWindow.on('close', (e) => {
    if (!isQuitting) {
      e.preventDefault();
      mainWindow.hide();
    }
  });
}

// 图标路径
const ICON_PATH = getAssetPath('icon.png');

function createTrayIcon() {
  // 使用应用主图标（自动缩放到托盘尺寸）
  if (fs.existsSync(ICON_PATH)) {
    const img = nativeImage.createFromPath(ICON_PATH);
    if (!img.isEmpty()) return img.resize({ width: 16, height: 16 });
  }
  // 极端后备：空白图标
  return nativeImage.createEmpty();
}

function createTray() {
  let trayIcon = createTrayIcon();
  tray = new Tray(trayIcon);

  const contextMenu = Menu.buildFromTemplate([
    { label: '显示主窗口', click: () => { if (mainWindow) { mainWindow.show(); mainWindow.focus(); } } },
    { label: '切换设备组', accelerator: HOTKEY, click: () => switchDevices() },
    { type: 'separator' },
    { label: '创建桌面快捷方式', click: () => createDesktopShortcut() },
    { type: 'separator' },
    { label: '开机自启', type: 'checkbox', checked: app.getLoginItemSettings().openAtLogin,
      click: (menuItem) => { app.setLoginItemSettings({ openAtLogin: menuItem.checked }); } },
    { type: 'separator' },
    { label: '退出', click: () => { isQuitting = true; app.quit(); } },
  ]);

  tray.setToolTip('Sound Switcher - 音频设备组切换');
  tray.setContextMenu(contextMenu);
  tray.on('double-click', () => { if (mainWindow) { mainWindow.show(); mainWindow.focus(); } });
}

// 切换设备组（循环）
async function switchDevices() {
  if (!mainWindow) return;
  try {
    const script = getPsPath('audio.ps1');
    const result = await runPowerShell(script, ['-Action', 'switch']);
    console.log('Switch result:', JSON.stringify(result));
    mainWindow.webContents.send('device-switched', result);
    await refreshDevices();
  } catch (err) {
    console.error('Switch failed:', err.message);
    mainWindow.webContents.send('switch-error', err.message);
  }
}

// 切换到指定组
async function switchToGroup(index) {
  const script = getPsPath('audio.ps1');
  return await runPowerShell(script, ['-Action', 'switch-to', '-ProfileIndex', index]);
}

// 获取设备列表
async function getDevices() {
  const script = getPsPath('audio.ps1');
  return await runPowerShell(script, ['-Action', 'list']);
}

async function refreshDevices() {
  try {
    const devices = await getDevices();
    if (mainWindow) mainWindow.webContents.send('devices-updated', devices);
    return devices;
  } catch (err) {
    console.error('Get devices failed:', err.message);
    if (mainWindow) mainWindow.webContents.send('devices-error', err.message);
    return null;
  }
}

// 创建桌面快捷方式
async function createDesktopShortcut() {
  try {
    const shortcutScript = getPsPath('create-shortcut.ps1');

    // 打包后用 exe 路径，开发模式用 start.bat
    let targetPath;
    if (isAsar && app.getPath) {
      // 打包后: 使用当前运行的 exe
      targetPath = process.execPath;
    } else {
      targetPath = path.join(__dirname, 'start.bat');
    }

    const result = await runPowerShell(shortcutScript, [
      '-TargetPath', targetPath,
      '-IconPath', ICON_PATH,
      '-ShortcutName', 'Sound Switcher',
    ]);

    if (result && result.success) {
      console.log('Desktop shortcut created:', result.path);
      if (mainWindow) mainWindow.webContents.send('shortcut-created', result);
      // 弹出系统通知
      const { Notification } = require('electron');
      if (Notification.isSupported()) {
        new Notification({
          title: 'Sound Switcher',
          body: '桌面快捷方式已创建',
          icon: ICON_PATH,
        }).show();
      }
    } else {
      console.error('Shortcut creation failed:', result);
    }
    return result;
  } catch (err) {
    console.error('Shortcut creation error:', err.message);
    return { success: false, error: err.message };
  }
}

// ====== IPC Handlers ======
ipcMain.handle('get-devices', async () => await refreshDevices());

ipcMain.handle('switch-devices', async () => await switchDevices());

ipcMain.handle('switch-to-group', async (_event, index) => {
  try {
    const result = await switchToGroup(index);
    if (mainWindow) mainWindow.webContents.send('device-switched', result);
    await refreshDevices();
    return result;
  } catch (err) {
    return { success: false, error: err.message };
  }
});

ipcMain.handle('save-group', async (_event, name, outputDeviceId, inputDeviceId) => {
  return await runPowerShellWithJson('save-group', {
    ProfileName: name,
    OutputDeviceId: outputDeviceId || '',
    InputDeviceId: inputDeviceId || '',
  });
});

ipcMain.handle('delete-group', async (_event, name) => {
  return await runPowerShellWithJson('delete-group', { DeleteProfile: name });
});

ipcMain.handle('update-group', async (_event, oldName, newName, outputDeviceId, inputDeviceId) => {
  return await runPowerShellWithJson('update-group', {
    DeleteProfile: oldName,
    ProfileName: newName || '',
    OutputDeviceId: outputDeviceId || '',
    InputDeviceId: inputDeviceId || '',
  });
});

ipcMain.handle('get-hotkey', () => HOTKEY);

ipcMain.handle('close-window', () => { if (mainWindow) mainWindow.hide(); });
ipcMain.handle('minimize-window', () => { if (mainWindow) mainWindow.minimize(); });

ipcMain.handle('create-shortcut', async () => await createDesktopShortcut());

// ====== 单实例锁 ======
const gotTheLock = app.requestSingleInstanceLock();
if (!gotTheLock) {
  app.quit();
} else {
  app.on('second-instance', () => {
    // 用户尝试启动第二个实例，激活已有窗口
    if (mainWindow) {
      if (!mainWindow.isVisible()) mainWindow.show();
      if (mainWindow.isMinimized()) mainWindow.restore();
      mainWindow.focus();
    }
  });
}

// ====== 应用启动 ======
app.whenReady().then(async () => {
  createWindow();
  createTray();

  const registered = globalShortcut.register(HOTKEY, () => {
    console.log(`${HOTKEY} pressed - switching device group`);
    switchDevices();
  });

  if (!registered) console.error(`Failed to register hotkey: ${HOTKEY}`);

  setTimeout(() => refreshDevices(), 1000);
});

app.on('window-all-closed', () => { /* 保持在托盘 */ });
app.on('before-quit', () => { isQuitting = true; });
app.on('will-quit', () => { globalShortcut.unregisterAll(); });
