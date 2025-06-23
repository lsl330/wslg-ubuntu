#!/bin/bash

# WSL Xfce Desktop Installer
# Fixed plocate initialization hang issue
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

# 修复plocate初始化卡住问题
echo "修复plocate数据库初始化问题..."
if [ -f /etc/updatedb.conf ]; then
    sudo sed -i 's|PRUNEPATHS=""|PRUNEPATHS="/mnt"|g' /etc/updatedb.conf
    sudo sed -i 's|PRUNEFS=""|PRUNEFS="ntfs"|g' /etc/updatedb.conf
else
    echo 'PRUNE_BIND_MOUNTS="yes"' | sudo tee /etc/updatedb.conf
    echo 'PRUNEPATHS="/tmp /var/spool /mnt"' | sudo tee -a /etc/updatedb.conf
    echo 'PRUNEFS="NFS nfs nfs4 rpc_pipefs afs binfmt_misc proc smbfs autofs iso9660 ncpfs coda devpts ftpfs devfs ntfs"' | sudo tee -a /etc/updatedb.conf
fi

# 安装Xfce桌面环境
echo "安装Xfce桌面环境 (约1GB，请耐心等待)..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y xubuntu-desktop

# 修复WSLg权限问题
echo "修复WSLg目录权限..."
sudo chmod 1777 /tmp
[ -d /usr/share/desktop-directories ] && sudo chmod 1777 /usr/share/desktop-directories || true

# 配置XWayland
echo "配置XWayland..."
sudo tee /etc/systemd/system/xwayland.service >/dev/null <<EOF
[Unit]
Description=XWayland Service
After=network.target

[Service]
Type=simple
Environment=DISPLAY=:0
ExecStart=/usr/bin/Xwayland
Restart=always

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable xwayland.service

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
sudo tee /usr/local/bin/xubuntu >/dev/null <<EOF
#!/bin/bash

# 显示关机提示
echo -e "\n\033[1;33m⚠️ 请勿直接关闭窗口! 请使用以下方式关机:\033[0m"
echo -e "\033[1;36m1. 桌面菜单: Xfce菜单 → 关机"
echo -e "2. 终端命令: sudo poweroff\033[0m\n"

# 等待systemd初始化
echo "启动systemd服务..."
sudo systemctl start systemd-user-sessions.service

# 启动Xfce
echo "启动Xfce桌面环境 (首次启动需30-60秒)..."
export DISPLAY=:0
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=XFCE
xfce4-session
EOF

sudo chmod +x /usr/local/bin/xubuntu

# 完成提示
echo -e "\n\033[1;32m✅ 安装完成！请按以下步骤操作："
echo -e "1. 重启WSL: 在Windows终端执行: wsl --shutdown"
echo -e "2. 重新启动WSL后，输入命令: xubuntu"
echo -e "3. 首次启动需要30-60秒初始化，请耐心等待\033[0m\n"
