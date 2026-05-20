# Sound Switcher

> Windows 音频设备组一键切换工具 —— 液态玻璃风格 UI，支持全局快捷键

## 快速下载

**无需安装，下载即用：**

👉 [Sound-Switcher-v1.0.0-win-x64.zip](release/Sound-Switcher-v1.0.0-win-x64.zip)（约 105 MB）

下载后解压，直接运行 **`Sound Switcher.exe`** 即可。

---

## 功能特性

| 功能 | 说明 |
|------|------|
| 🔄 **循环切换设备组** | `Ctrl+Shift+F12` 按顺序轮换预配置的音频设备组 |
| 📋 **设备组管理** | 创建多个「输出+输入」设备配对（如：游戏模式，会议模式） |
| 🎯 **一键切换** | 点击即切，输出（耳机/音箱）和输入（麦克风）设备同时切换 |
| 🪟 **液态玻璃 UI** | 毛玻璃效果 + 动态渐变背景，赏心悦目 |
| 📌 **系统托盘** | 关闭按钮最小化到托盘，右键菜单完整操作 |
| 🔒 **单实例运行** | 自动检测已运行实例，避免重复启动 |

## 安装方法

### 方法一：直接运行（推荐，无需安装）

1. 下载 `Sound-Switcher-v1.0.0-win-x64.zip`
2. 解压到任意目录
3. 双击 **`Sound Switcher.exe`** 运行

> 首次运行后可右键 → 创建桌面快捷方式

### 方法二：从源码运行

```bash
git clone <本项目地址>
cd sound-switcher
npm install
npm start
```

### 方法三：自行打包

```bash
npm install
npm run build
# 打包产物在 release/win-unpacked/
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
- **一键切换按钮**：点击主界面「切换下一组」按钮

### 托盘操作

- **双击托盘图标**：显示主界面
- **托盘右键菜单**：
  - 显示主窗口
  - 切换设备组（显示当前快捷键）
  - 创建桌面快捷方式
  - 开机自启（勾选即生效）
  - 退出

## 系统要求

- Windows 10/11（64位）
- 无需额外依赖

## 项目结构

```
sound-switcher/
├── main.js              # Electron 主进程（含单实例锁、asar 路径兼容）
├── preload.js           # IPC 桥接
├── renderer/
│   ├── index.html       # 主界面
│   ├── style.css       # 液态玻璃样式
│   └── renderer.js     # 前端逻辑
├── scripts/
│   ├── audio.ps1        # 音频设备管理 PowerShell 脚本
│   ├── AudioAPI.cs      # Windows Core Audio API C# 封装
│   └── create-shortcut.ps1  # 桌面快捷方式创建
├── assets/
│   └── icon.png         # 应用图标
├── release/
│   ├── win-unpacked/    # ⭐ 可直接分发的打包产物
│   │   └── Sound Switcher.exe
│   └── Sound-Switcher-v1.0.0-win-x64.zip  # ⭐ 便携版压缩包
├── package.json
└── README.md
```

## 技术实现

- **框架**：Electron 30 + 原生窗口透明
- **音频 API**：Windows Core Audio API via C# P/Invoke
- **打包**：electron-builder，asar + asarUnpack 分离可执行脚本
- **编码处理**：PowerShell 强制 UTF-8 + 临时 JSON 文件传参解决中文乱码
- **单实例**：Electron `requestSingleInstanceLock` API

## License

MIT
