# Sound Switcher v2 - 一键切换音频设备组

基于 **Electron** 的 Windows 桌面应用，支持**全局快捷键一键循环切换**多组音频输出+输入设备配对。

## ✨ 核心功能

| 功能 | 说明 |
|------|------|
| 🔄 **循环切换设备组** | `Ctrl+Shift+F12` 按顺序轮换设备组 |
| 📋 **设备组管理** | 创建多个输入+输出配对（如：游戏模式、会议模式） |
| 🎯 **一键切换** | 点击组或在界面切换，输出和输入设备同时变动 |
| 🪟 **液态玻璃 UI** | 毛玻璃效果 + 动态渐变背景 |
| 📌 **系统托盘** | 关闭窗口最小化到托盘，双击显示 |

## 🚀 使用方法

### 创建第一个设备组
1. 点击「设备组」区域的 [+] 按钮
2. 输入组名称（如：游戏模式）
3. 选择输出设备（耳机）和输入设备（麦克风）
4. 点击「保存组」

### 创建第二个设备组
5. 再次点击 [+] 创建第二个组（如：会议模式）
6. 选择另一组设备配对并保存

### 日常使用
7. 按下 `Ctrl+Shift+F12` 即可在两组之间循环切换
8. 或点击界面上的「切换下一组」按钮
9. 也可直接点击某个设备组立即切换到该组

## 🛠️ 环境要求
- Windows 10/11
- Node.js 16+

## 📦 运行
```bash
cd sound-switcher
npm install
npm start
```

## 📁 项目结构
```
sound-switcher/
├── main.js              # Electron 主进程
├── preload.js           # IPC 桥接
├── renderer/
│   ├── index.html       # 主界面（设备组面板 + 编辑面板 + 设备列表）
│   ├── style.css        # 液态玻璃 CSS
│   └── renderer.js      # 前端逻辑
├── scripts/
│   ├── AudioAPI.cs      # Windows Core Audio API C#封装
│   └── audio.ps1        # PowerShell 音频管理（组管理 + 切换）
└── package.json
```

## 🔧 技术实现
- **编码修复**：PowerShell 强制 UTF-8 输出 + Node.js buffer 解码 + 中文参数通过临时 JSON 文件传递
- **设备管理**：Windows Core Audio API via C# P/Invoke
- **组管理**：JSON 配置文件存储多组设备配对，activeIndex 追踪当前组
- **循环切换**：快捷键触发 → 计算 `(activeIndex + 1) % totalGroups` → 切换目标组
