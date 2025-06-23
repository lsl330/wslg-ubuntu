#!/bin/bash

# WSL2 Xfce Desktop with WSLg (XWayland) - 完美实现原生桌面环境
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
sudo apt-get upgrade -y

# 安装必要工具
echo "安装必要工具..."
sudo apt-get install -y wget

# 安装Xfce桌面环境和必要组件
echo "安装Xfce桌面环境和必要组件..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    xubuntu-desktop \
    xwayland \
    dbus-x11 \
    policykit-1-gnome \
    xfce4-notifyd \
    xfce4-power-manager \
    xfce4-screenshooter \
    xfce4-taskmanager \
    xfce4-terminal \
    xfce4-whiskermenu-plugin

# 配置区域设置
echo "配置区域设置..."
echo "LANG=en_US.UTF-8" | sudo tee -a /etc/default/locale

# 下载并配置wslg-fix.service
echo "下载并配置wslg-fix.service..."
sudo tee /etc/systemd/system/wslg-fix.service >/dev/null <<'EOF'
[Unit]
Description=Fix WSLg issues

[Service]
Type=oneshot
ExecStart=-/usr/bin/umount /tmp/.X11-unix
ExecStart=/usr/bin/rm -rf /tmp/.X11-unix
ExecStart=/usr/bin/mkdir /tmp/.X11-unix
ExecStart=/usr/bin/chmod 1777 /tmp/.X11-unix
ExecStart=/usr/bin/ln -sf /mnt/wslg/.X11-unix/X0 /tmp/.X11-unix/X0
ExecStart=/usr/bin/chmod 0777 /mnt/wslg/runtime-dir
ExecStart=/usr/bin/chmod 0666 /mnt/wslg/runtime-dir/wayland-0.lock

[Install]
WantedBy=multi-user.target
EOF

sudo chmod 644 /etc/systemd/system/wslg-fix.service
sudo systemctl daemon-reload
sudo systemctl enable wslg-fix.service

# 修改user-runtime-dir@.service
echo "修改user-runtime-dir@.service..."
sudo tee /etc/systemd/system/user-runtime-dir@.service.d/override.conf >/dev/null <<'EOF'
[Service]
ExecStartPost=-/usr/bin/rm -f /run/user/%i/wayland-0 /run/user/%i/wayland-0.lock
EOF

# 设置默认启动目标
echo "设置默认启动目标..."
sudo systemctl set-default multi-user.target

# 备份原始Xorg
echo "备份原始Xorg..."
sudo cp /usr/bin/Xorg /usr/bin/Xorg.original

# 创建Xwayland替换脚本
echo "创建Xwayland替换脚本..."
sudo tee /usr/bin/Xorg.Xwayland >/dev/null <<'EOF'
#!/bin/bash
for arg do
  shift
  case $arg in
    vt*)
      set -- "$@" "${arg//vt/tty}"
      ;;
    -keeptty)
      ;;
    -novtswitch)
      ;;
    *)
      set -- "$@" "$arg"
      ;;
  esac
done

# 检查并创建运行时目录
if [ ! -d $HOME/runtime-dir ]
then
  mkdir $HOME/runtime-dir
  ln -s /mnt/wslg/runtime-dir/wayland-0 /mnt/wslg/runtime-dir/wayland-0.lock $HOME/runtime-dir/
fi

# 设置环境变量
export XDG_RUNTIME_DIR=$HOME/runtime-dir

# 查找可用显示编号
for displayNumber in $(seq 1 100)
do
  [ ! -e /tmp/.X11-unix/X$displayNumber ] && break
done

# 启动Xwayland
command=("/usr/bin/Xwayland" ":${displayNumber}" "-geometry" "1920x1080" "$@")
systemd-cat -t /usr/bin/Xorg echo "Starting Xwayland:" "${command[@]}"
exec "${command[@]}"
EOF

sudo chmod 0755 /usr/bin/Xorg.Xwayland
sudo ln -sf /usr/bin/Xorg.Xwayland /usr/bin/Xorg

# 配置显示器分辨率
echo "配置显示器分辨率..."
mkdir -p ~/.config
cat > ~/.config/monitors.xml <<'EOF'
<monitors version="2">
  <configuration>
    <logicalmonitor>
      <x>0</x>
      <y>0</y>
      <scale>1</scale>
      <primary>yes</primary>
      <monitor>
        <monitorspec>
          <connector>XWAYLAND0</connector>
          <vendor>unknown</vendor>
          <product>unknown</product>
          <serial>unknown</serial>
        </monitorspec>
        <mode>
          <width>1920</width>
          <height>1080</height>
          <rate>59.963</rate>
        </mode>
      </monitor>
    </logicalmonitor>
  </configuration>
</monitors>
EOF

# 创建启动脚本
echo "创建启动脚本..."
sudo tee /usr/local/bin/xfce-desktop >/dev/null <<'EOF'
#!/bin/bash

# 启动Xfce桌面环境的正确方式
echo "启动Xfce桌面环境..."

# 设置环境变量
export DISPLAY=:0
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=XFCE
export NO_AT_BRIDGE=1

# 启动图形界面
echo "启动图形目标..."
sudo systemctl start graphical.target

# 等待桌面启动
echo "等待桌面初始化完成..."
sleep 5

# 保持脚本运行
echo -e "\n\033[1;33m⚠️ 请勿直接关闭此窗口!"
echo -e "请使用系统菜单或命令关机: sudo poweroff\033[0m\n"
echo "桌面已启动，按Ctrl+C可退出此脚本（但会关闭桌面）"
echo "建议最小化此窗口而不是关闭"

while true; do
    sleep 3600
done
EOF

sudo chmod +x /usr/local/bin/xfce-desktop

# 创建桌面快捷方式
echo "创建桌面快捷方式..."
mkdir -p ~/Desktop
cat > ~/Desktop/Xfce.desktop <<'EOF'
[Desktop Entry]
Name=Xfce Desktop
Comment=Start Xfce Desktop Environment
Exec=/usr/local/bin/xfce-desktop
Icon=/usr/share/icons/hicolor/scalable/apps/xfce4-session.svg
Terminal=true
Type=Application
Categories=Utility;
EOF
chmod +x ~/Desktop/Xfce.desktop

# 修复权限问题
echo "修复权限问题..."
sudo chmod 1777 /tmp
sudo chmod a+w /mnt/wslg/runtime-dir/wayland-0.lock

# 完成提示
echo -e "\n\033[1;32m✅ 安装完成！请按以下步骤操作："
echo -e "1. 重启WSL: 在Windows终端执行: wsl --shutdown"
echo -e "2. 重新启动WSL后，输入命令: xfce-desktop"
echo -e "3. 首次启动需要30-60秒初始化，请耐心等待\033[0m"
echo -e "\n\033[1;33m注意：请使用系统菜单或'sudo poweroff'命令关机，不要直接关闭窗口!\033[0m"
echo -e "\033[1;34m💡 如果遇到问题，请检查日志: journalctl -b -t /usr/bin/Xorg\033[0m"
