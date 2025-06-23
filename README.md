# WSL轻量级Xfce桌面环境一键部署方案

> 一键安装配置Xfce桌面环境，专为WSL优化的轻量级解决方案

## 快速开始

### 部署命令

```bash
curl -o wslg-ubuntu.sh https://raw.githubusercontent.com/lsl330/wslg-ubuntu/refs/heads/main/wslg-ubuntu.sh && chmod +x wslg-ubuntu.sh && ./wslg-ubuntu.sh
```

## 🌟 功能特点

### 完全无人值守
- ✅ 自动处理所有配置和确认
- ✅ 使用非交互模式安装软件包

### 桌面环境优化
- 🖥️ 轻量级Xfce桌面环境（基于Xubuntu）
- 🖼️ 预设1920x1080分辨率配置
- 🔄 自动配置XWayland替换Xorg

### 一键启动体验
- 🚀 安装后只需输入 `xubuntu` 即可启动桌面
- ⚙️ 自动处理服务启动和状态检查

### 关键配置优化
- ⚡ 自动启用systemd支持
- 🔒 修复WSLg目录权限问题
- 📺 设置优化的显示器分辨率

### 安全关机提醒
- ⚠️ 桌面启动时显示正确关机提示
- 🛡️ 防止直接关闭窗口导致文件损坏

## ⚠️ 注意事项

### 首次启动时间
- ⏳ 第一次启动需要 **30-60秒**（初始化配置）
- ⚡ 后续启动仅需 **5-10秒**

### 系统要求
- **Windows版本**：
  - Windows 11
  - Windows 10 21H2或更高版本
- **必需功能**：
  - ✅ WSL2 已启用
  - ✅ WSLg 支持已激活

### 网络与安装
- 🌐 安装需要下载约 **1GB** 数据
- 📶 确保稳定的网络连接

### 分辨率调整
如需修改分辨率：
1. 编辑配置文件：`~/.config/monitors.xml`
2. 修改对应的宽度和高度值

```xml
<monitors version="2">
  <configuration>
    <logicalmonitor>
      <mode>
        <width>1920</width>
        <height>1080</height>
      </mode>
    </logicalmonitor>
  </configuration>
</monitors>
```

## 安全关机
为避免文件损坏，请始终使用以下方式关机：
1. 通过桌面系统菜单关机
2. 或在终端执行：
```bash
sudo poweroff
```

❌ **切勿直接关闭终端窗口！** 否则可能导致文件系统损坏！

## 🚀 使用说明
1. **安装要求**：确保已启用WSL2和WSLg支持
2. **执行安装**：运行提供的安装脚本
3. **启动桌面**：安装完成后在WSL终端输入：
```bash
xubuntu
```
4. **日常使用**：
   - 每次使用后通过系统菜单或`sudo poweroff`关机
   - 下次启动只需再次输入`xubuntu`
