#!/bin/bash

# WSL Xfce Desktop Installer
# 修复 Weston 冲突问题
# GitHub: https://github.com/lsl330/wslg-ubuntu

set -e

# 启用systemd
echo "启用systemd支持..."
sudo tee /etc/wsl.conf >/dev/null <<EOF
[boot]
systemd=true
EOF

# 更新系统
echo "更新系统包列表..."
sudo apt-get update

# 1. 预先创建plocate配置文件
echo "创建plocate配置文件..."
sudo tee /etc/updatedb.conf >/dev/null <<'EOF'
PRUNE_BIND_MOUNTS="yes"
PRUNENAMES=".git .bzr .hg .svn"
PRUNEPATHS="/tmp /var/spool /var/lock /var/cache /var/lib/lxcfs /var/lib/docker /mnt"
PRUNEFS="NFS nfs nfs4 rpc_pipefs afs binfmt_misc proc smbfs autofs iso9660 ncpfs coda devpts ftpfs devfs mfs shfs sysfs cifs lustre_lite tmpfs usbfs udf fuse.glusterfs fuse.sshfs curlftpfs ecryptfs fusesmb devtmpfs"
EOF

# 2. 禁用plocate安装后脚本
echo "禁用plocate安装后脚本..."
sudo mkdir -p /var/lib/dpkg/info/
sudo tee /var/lib/dpkg/info/plocate.postinst >/dev/null <<'EOF'
#!/bin/sh
set -e
echo "跳过plocate数据库初始化 (已在WSL中预先配置)"
exit 0
EOF
sudo chmod 0755 /var/lib/dpkg/info/plocate.postinst

# 3. 安装Xfce桌面环境
echo "安装Xfce桌面环境 (约1GB，请耐心等待)..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-downgrades --allow-remove-essential xubuntu-desktop

# 4. 安装缺失的依赖和解决冲突的包
echo "安装缺失的依赖和解决冲突..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    xfce4-session \
    xfce4-panel \
    xfdesktop4 \
    xfwm4 \
    xfce4-settings \
    xfce4-appfinder \
    lightdm \
    dbus-x11 \
    policykit-1-gnome \
    xfce4-notifyd \
    xfce4-power-manager \
    xfce4-screenshooter \
    xfce4-taskmanager \
    xfce4-terminal \
    xfce4-whiskermenu-plugin

# 5. 禁用冲突的WSLg服务
echo "禁用冲突的WSLg服务..."
sudo systemctl disable weston-launch 2>/dev/null || true
sudo systemctl mask weston-launch 2>/dev/null || true
sudo systemctl disable xwayland 2>/dev/null || true
sudo systemctl mask xwayland 2>/dev/null || true

# 6. 手动安全初始化plocate
echo "安全初始化plocate数据库..."
sudo mkdir -p /var/lib/plocate
sudo updatedb --require-visibility 0 2>/dev/null || true
echo "plocate数据库初始化完成"

# 修复WSLg权限问题
echo "修复WSLg目录权限..."
sudo chmod 1777 /tmp
[ -d /usr/share/desktop-directories ] && sudo chmod 1777 /usr/share/desktop-directories || true

# 设置默认分辨率
echo "配置默认分辨率1920x1080..."
mkdir -p ~/.config
cat > ~/.config/monitors.xml <<EOF
<monitors version="2">
  <configuration>
    <logicalmonitor>
      <x>0</x>
      <y>0</y>
      <scale>1</scale>
      <primary>yes</primary>
      <mode>
        <width>1920</width>
        <height>1080</height>
        <rate>60.0</rate>
      </mode>
    </logicalmonitor>
  </configuration>
</monitors>
EOF

# 创建启动脚本
echo "创建启动脚本..."
sudo tee /usr/local/bin/xubuntu >/dev/null <<'EOF'
#!/bin/bash

# 停止冲突的服务
sudo systemctl stop weston-launch 2>/dev/null || true
sudo systemctl stop xwayland 2>/dev/null || true
killall weston 2>/dev/null || true
killall Xwayland 2>/dev/null || true

# 显示关机提示
echo -e "\n\033[1;33m⚠️ 请勿直接关闭窗口! 请使用以下方式关机:\033[0m"
echo -e "\033[1;36m1. 桌面菜单: Xfce菜单 → 关机"
echo -e "2. 终端命令: sudo poweroff\033[0m\n"

# 启动DBUS服务
echo "启动DBUS服务..."
sudo service dbus start

# 启动显示管理器
echo "启动LightDM服务..."
sudo service lightdm start 2>/dev/null || true

# 设置环境变量
export DISPLAY=:0
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=XFCE

# 启动Xfce桌面环境
echo "启动Xfce桌面环境 (首次启动需30-60秒)..."
startxfce4

# 如果上述命令失败，尝试备用方法
if [ $? -ne 0 ]; then
    echo "尝试备用启动方法..."
    xfce4-session
fi
EOF

sudo chmod +x /usr/local/bin/xubuntu

# 创建桌面快捷方式
echo "创建桌面快捷方式..."
mkdir -p ~/Desktop
cat > ~/Desktop/Xfce.desktop <<EOF
[Desktop Entry]
Name=Xfce Desktop
Comment=Start Xfce Desktop Environment
Exec=/usr/local/bin/xubuntu
Icon=/usr/share/icons/hicolor/scalable/apps/xfce4-session.svg
Terminal=true
Type=Application
Categories=Utility;
EOF
chmod +x ~/Desktop/Xfce.desktop

# 完成提示
echo -e "\n\033[1;32m✅ 安装完成！请按以下步骤操作："
echo -e "1. 重启WSL: 在Windows终端执行: wsl --shutdown"
echo -e "2. 重新启动WSL后，输入命令: xubuntu"
echo -e "3. 首次启动需要30-60秒初始化，请耐心等待\033[0m"
echo -e "\n\033[1;33m注意：首次启动时可能会看到一些警告信息，稍等片刻桌面会完全加载。\033[0m"
