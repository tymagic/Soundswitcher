# Sound Switcher

> Windows 音频设备组一键切换工具 —— 液态玻璃风格 UI，支持全局快捷键

## 下载

### 安装包（推荐）

👉 **[Sound-Switcher-Setup-v1.0.0.exe](https://github.com/tymagic/Soundswitcher/releases/latest)**

双击运行，自动安装到 `C:\Program Files\SoundSwitcher\`，创建桌面和开始菜单快捷方式，支持卸载。

### 便携版

👉 **[Sound-Switcher-v1.0.0-win-x64.zip](https://github.com/tymagic/Soundswitcher/releases/latest)**

下载后解压到任意目录，双击 `Sound Switcher.exe` 运行（无需安装）。

> **注意：** 如果装了腾讯电脑管家/360 等安全软件，建议使用安装包方式，或将解压目录加入信任区。

---

## 功能特性

| 功能 | 说明 |
|------|------|
| 🔄 **循环切换设备组** | `Ctrl+Shift+F12` 按顺序轮换预配置的音频设备组 |
| 📋 **设备组管理** | 创建多个「输出+输入」设备配对（如：游戏模式，会议模式） |
| 🎯 **一键切换** | 点击即切，输出（耳机/音箱）和输入（麦克风）设备同时切换 |
| 🪟 **液态玻璃 UI** | 毛玻璃效果 + 动态渐变背景 |
| 📌 **系统托盘** | 关闭按钮最小化到托盘，右键菜单完整操作 |
| 🔒 **单实例运行** | 自动检测已运行实例，避免重复启动 |

## 从源码运行

```bash
git clone https://github.com/tymagic/Soundswitcher.git
cd sound-switcher
npm install
npm start
```

## 自行打包

```bash
npm install
npm run build
# 打包产物在 release/win-unpacked/

# 或生成安装包：
powershell -File installer/build-installer.ps1
```

## 使用说明

### 首次使用

1. 点击「设备组」区域的 **[+]** 按钮
2. 输入组名称（如：`游戏模式`）
3. 选择输出设备（耳机/音箱）和输入设备（麦克风）
4. 点击「保存组」
5. 重复以上步骤，创建第二个组（如：`会议模式`）

### 日常使用

- **快捷键切换**：按 `Ctrl+Shift+F12` 在已配置的设备组之间循环切换
- **界面切换**：点击任意设备组卡片，立即切换到该组
- **托盘右键菜单**：显示主窗口 / 切换设备组 / 创建桌面快捷方式 / 开机自启 / 退出

## 系统要求

- Windows 10/11（64位）
- 无需额外依赖

## 项目结构

```
sound-switcher/
├── main.js              # Electron 主进程
├── preload.js           # IPC 桥接
├── renderer/            # 前端界面
├── scripts/             # PowerShell/C# 音频 API
├── assets/              # 图标资源
├── installer/           # 安装包构建脚本
├── package.json
└── README.md
```

## 技术实现

- **框架**：Electron 30
- **音频 API**：Windows Core Audio API via C# P/Invoke
- **打包**：electron-builder + asar
- **安装包**：自解压 bat + zip 合并 exe

## License

MIT
