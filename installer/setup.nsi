; Sound Switcher NSIS Installer Script
; UTF-8 encoding

Unicode true
!include "MUI2.nsh"
!include "FileFunc.nsh"

; ── 基本信息 ──
!define PRODUCT_NAME "Sound Switcher"
!define PRODUCT_VERSION "1.0.0"
!define PRODUCT_PUBLISHER "tymagic"
!define PRODUCT_WEB_SITE "https://github.com/tymagic/Soundswitcher"
!define PRODUCT_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"

Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "..\Sound-Switcher-Setup-v${PRODUCT_VERSION}.exe"
InstallDir "$PROGRAMFILES64\${PRODUCT_NAME}"
RequestExecutionLevel admin
SetCompressor lzma
BrandingText "${PRODUCT_NAME}"

; ── 界面设置 ──
!define MUI_ABORTWARNING
!define MUI_ICON "..\release\win-unpacked\resources\app.asar.unpacked\assets\icon.png"
!define MUI_UNICON "..\release\win-unpacked\resources\app.asar.unpacked\assets\icon.png"

; 安装页面
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "..\LICENSE"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

; 卸载页面
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "SimpChinese"

; ── 安装区段 ──
Section "Install"
  SetOutPath "$INSTDIR"

  ; 复制所有文件
  File /r "..\release\win-unpacked\*.*"

  ; 创建开始菜单快捷方式
  CreateDirectory "$SMPROGRAMS\${PRODUCT_NAME}"
  CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\${PRODUCT_NAME}.lnk" "$INSTDIR\Sound Switcher.exe" "" "$INSTDIR\Sound Switcher.exe" 0
  CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\卸载 Sound Switcher.lnk" "$INSTDIR\uninst.exe"

  ; 创建桌面快捷方式
  CreateShortCut "$DESKTOP\${PRODUCT_NAME}.lnk" "$INSTDIR\Sound Switcher.exe" "" "$INSTDIR\Sound Switcher.exe" 0

  ; 写入卸载信息
  WriteUninstaller "$INSTDIR\uninst.exe"
  WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "DisplayName" "${PRODUCT_NAME}"
  WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "UninstallString" "$INSTDIR\uninst.exe"
  WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "DisplayIcon" "$INSTDIR\Sound Switcher.exe,0"
  WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "DisplayVersion" "${PRODUCT_VERSION}"
  WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
  WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "URLInfoAbout" "${PRODUCT_WEB_SITE}"
  WriteRegDWORD HKLM "${PRODUCT_UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKLM "${PRODUCT_UNINST_KEY}" "NoRepair" 1

  ; 计算安装大小
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0
  WriteRegDWORD HKLM "${PRODUCT_UNINST_KEY}" "EstimatedSize" "$0"
SectionEnd

; ── 卸载区段 ──
Section "Uninstall"
  ; 停止正在运行的程序
  nsExec::ExecToStack 'taskkill /f /im "Sound Switcher.exe"'

  ; 删除文件
  RMDir /r "$INSTDIR"

  ; 删除快捷方式
  Delete "$SMPROGRAMS\${PRODUCT_NAME}\${PRODUCT_NAME}.lnk"
  Delete "$SMPROGRAMS\${PRODUCT_NAME}\卸载 Sound Switcher.lnk"
  RMDir "$SMPROGRAMS\${PRODUCT_NAME}"
  Delete "$DESKTOP\${PRODUCT_NAME}.lnk"

  ; 删除注册表
  DeleteRegKey HKLM "${PRODUCT_UNINST_KEY}"
SectionEnd
