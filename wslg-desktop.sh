#!/bin/bash

# WSL Multi-Desktop Installer with Multi-Language Support
# GitHub: https://github.com/lsl330/wslg-ubuntu

set -e

# 获取当前用户名
CURRENT_USER=$(whoami)

# 选择桌面环境
echo "Select desktop environment:"
echo "1. GNOME (Ubuntu Desktop)"
echo "2. Xfce (Xubuntu Desktop)"
echo "3. Deepin (Deepin Desktop)"
read -p "Enter your choice [1-3]: " desktop_choice

# 如果不是Deepin桌面，则选择语言
if [ "$desktop_choice" != "3" ]; then
    echo "Select languages to install (comma separated):"
    echo "1. English"
    echo "2. Simplified Chinese"
    echo "3. Traditional Chinese"
    echo "4. Japanese"
    read -p "Enter your choices (e.g. 1,2,4): " lang_choices
fi

# 启用systemd
echo "Enabling systemd support..."
sudo tee /etc/wsl.conf >/dev/null <<EOF
[boot]
systemd=true
EOF

# 更新系统
echo "Updating package lists..."
sudo apt-get update

# 安装必要依赖（包括xrandr）
echo "Installing essential dependencies..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    x11-xserver-utils \
    mesa-utils \
    xdg-utils \
    dbus-user-session \
    policykit-1

# 如果不是Deepin桌面，则安装所选语言
if [ "$desktop_choice" != "3" ]; then
    IFS=',' read -ra langs <<< "$lang_choices"
    for lang in "${langs[@]}"; do
        case $lang in
            1)
                echo "Installing English support..."
                sudo apt-get install -y language-pack-en
                ;;
            2)
                echo "Installing Simplified Chinese support..."
                sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
                    language-pack-zh-hans \
                    fonts-noto-cjk \
                    fonts-noto-ui-core
                ;;
            3)
                echo "Installing Traditional Chinese support..."
                sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
                    language-pack-zh-hant \
                    fonts-arphic-ukai \
                    fonts-arphic-uming
                ;;
            4)
                echo "Installing Japanese support..."
                sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
                    language-pack-ja \
                    fonts-noto-cjk \
                    fonts-ipafont \
                    fonts-ipaexfont
                ;;
        esac
    done
    
    # 配置语言环境变量（仅非Deepin桌面）
    echo "Configuring language environment variables..."
    sudo tee -a /etc/environment >/dev/null <<EOF
LANG=en_US.UTF-8
LANGUAGE=en_US:en
EOF

    sudo locale-gen en_US.UTF-8
    sudo update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
fi

# 安装桌面环境
case $desktop_choice in
    1)
        echo "Installing GNOME desktop environment..."
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
            ubuntu-desktop \
            gnome-shell \
            gnome-control-center
        DESKTOP_NAME="GNOME"
        DESKTOP_LAUNCH="gnome-session"
        ;;
    2)
        echo "Installing Xfce desktop environment..."
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
            xubuntu-desktop \
            xfce4 \
            xfce4-goodies
        DESKTOP_NAME="Xfce"
        DESKTOP_LAUNCH="startxfce4"
        ;;
    3)
        echo "Installing Deepin desktop environment..."
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        deepin-desktop-environment-base \
            deepin-desktop-environment-cli \Add commentMore actions
            deepin-desktop-environment-core \
            deepin-default-settings \
            deepin-terminal \
            deepin-image-viewer \
            deepin-screen-recorder-plugin \
            deepin-screen-recorder \
            deepin-graphics-driver-manager \
            deepin-polkit-agent
        
        # 额外修复Deepin桌面所需的依赖
        sudo apt-get install -y \
            x11-xkb-utils \
            xserver-xorg-input-all \
            libqt5gui5 \
            libqt5dbus5 \
            libqt5x11extras5 \
            libxcb-util0 \
            libxcb-util1
        
        DESKTOP_NAME="Deepin"
        DESKTOP_LAUNCH="startdde"
        ;;
esac

# 公共安装组件
echo "Installing common components..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    xwayland \
    dbus-x11 \
    policykit-1-gnome \
    locales \
    fcitx fcitx-mozc fcitx-config-gtk \
    im-config \
    x11-xserver-utils \
    mesa-utils \
    xdg-utils

# 1. 预先创建plocate配置文件
echo "Creating plocate configuration..."
sudo tee /etc/updatedb.conf >/dev/null <<'EOF'
PRUNE_BIND_MOUNTS="yes"
PRUNENAMES=".git .bzr .hg .svn"
PRUNEPATHS="/tmp /var/spool /var/lock /var/cache /var/lib/lxcfs /var/lib/docker /mnt"
PRUNEFS="NFS nfs nfs4 rpc_pipefs afs binfmt_misc proc smbfs autofs iso9660 ncpfs coda devpts ftpfs devfs mfs shfs sysfs cifs lustre_lite tmpfs usbfs udf fuse.glusterfs fuse.sshfs curlftpfs ecryptfs fusesmb devtmpfs"
EOF

# 2. 禁用plocate安装后脚本
echo "Disabling plocate post-install script..."
sudo mkdir -p /var/lib/dpkg/info/
sudo tee /var/lib/dpkg/info/plocate.postinst >/dev/null <<'EOF'
#!/bin/sh
set -e
echo "Skipping plocate database initialization (pre-configured in WSL)"
exit 0
EOF
sudo chmod 0755 /var/lib/dpkg/info/plocate.postinst

# 3. 创建wslg-fix服务
echo "Creating wslg-fix service..."
sudo tee /etc/systemd/system/wslg-fix.service >/dev/null <<'EOF'
[Unit]
Description=Fix WSLg permissions
After=systemd-user-sessions.service

[Service]
Type=oneshot
ExecStart=-/usr/bin/umount /tmp/.X11-unix
ExecStart=/usr/bin/rm -rf /tmp/.X11-unix
ExecStart=/usr/bin/mkdir /tmp/.X11-unix
ExecStart=/usr/bin/chmod 1777 /tmp/.X11-unix
ExecStart=/usr/bin/ln -s /mnt/wslg/.X11-unix/X0 /tmp/.X11-unix/X0
ExecStart=/usr/bin/chmod 0777 /mnt/wslg/runtime-dir
ExecStart=/usr/bin/chmod 0666 /mnt/wslg/runtime-dir/wayland-0.lock

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable wslg-fix.service

# 4. 修复Wayland引用问题
echo "Fixing Wayland references..."
sudo mkdir -p /etc/systemd/system/user-runtime-dir@.service.d/
sudo tee /etc/systemd/system/user-runtime-dir@.service.d/override.conf >/dev/null <<'EOF'
[Service]
ExecStartPost=-/usr/bin/rm -f /run/user/%i/wayland-0 /run/user/%i/wayland-0.lock
EOF

# 5. 替换Xorg为Xwayland脚本
echo "Replacing Xorg with Xwayland script..."
sudo mv /usr/bin/Xorg /usr/bin/Xorg.original || true
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

if [ ! -d $HOME/runtime-dir ]
then
 mkdir $HOME/runtime-dir
 ln -s /mnt/wslg/.X11-unix/X0 /tmp/.X11-unix/X0
 ln -s /mnt/wslg/runtime-dir/wayland-0 /mnt/wslg/runtime-dir/wayland-0.lock $HOME/runtime-dir/
fi

export XDG_RUNTIME_DIR=$HOME/runtime-dir

for displayNumber in $(seq 1 100)
do
  [ ! -e /tmp/.X11-unix/X$displayNumber ] && break
done

# 获取当前分辨率
RESOLUTION=${RESOLUTION:-"1920x1080"}
command=("/usr/bin/Xwayland" ":${displayNumber}" "-geometry" "$RESOLUTION" "-fullscreen" "$@")

systemd-cat -t /usr/bin/Xorg echo "Starting Xwayland:" "${command[@]}"

exec "${command[@]}"
EOF

sudo chmod 0755 /usr/bin/Xorg.Xwayland
sudo ln -sf /usr/bin/Xorg.Xwayland /usr/bin/Xorg

# 6. 配置显示目标
echo "Configuring display target..."
sudo systemctl set-default multi-user.target

# 7. 手动安全初始化plocate
echo "Initializing plocate database safely..."
sudo mkdir -p /var/lib/plocate
sudo updatedb --require-visibility 0 2>/dev/null || true
echo "Plocate database initialized"

# 8. 修复WSLg权限问题
echo "Fixing WSLg directory permissions..."
sudo chmod 1777 /tmp
[ -d /usr/share/desktop-directories ] && sudo chmod 1777 /usr/share/desktop-directories || true

# 9. 自动检测分辨率并设置
echo "Detecting display resolution..."
if command -v xrandr &> /dev/null; then
    RESOLUTION=$(xrandr | grep '*' | head -n 1 | awk '{print $1}')
    if [ -z "$RESOLUTION" ]; then
        RESOLUTION="1920x1080"
        echo "Using default resolution: $RESOLUTION"
    else
        echo "Detected resolution: $RESOLUTION"
    fi
else
    RESOLUTION="1920x1080"
    echo "xrandr not installed, using default resolution: $RESOLUTION"
fi

# 创建分辨率配置文件
echo "Configuring resolution $RESOLUTION..."
mkdir -p ~/.config
cat > ~/.config/monitors.xml <<EOF
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
          <width>${RESOLUTION%x*}</width>
          <height>${RESOLUTION#*x}</height>
          <rate>60</rate>
        </mode>
      </monitor>
    </logicalmonitor>
  </configuration>
</monitors>
EOF

# 为GDM用户复制配置文件
[ -d /var/lib/gdm3 ] && sudo mkdir -p /var/lib/gdm3/.config && \
    sudo cp ~/.config/monitors.xml /var/lib/gdm3/.config/ && \
    sudo chown -R gdm:gdm /var/lib/gdm3/.config/ || true

# 10. 输入法配置（仅非Deepin桌面）
if [ "$desktop_choice" != "3" ]; then
    echo "Configuring input methods..."
    tee -a ~/.profile >/dev/null <<'EOF'
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
EOF
fi

# 11. 创建统一启动命令（解决Deepin启动问题）
echo "Creating unified desktop launch command with Deepin fixes..."
sudo tee /usr/local/bin/wslg-desktop >/dev/null <<EOF
#!/bin/bash

# 解决dbus连接问题
echo "Starting systemd user session..."
systemctl restart user@\$(id -u).service
sleep 2

# 显示关机提示
echo -e "\n\033[1;33m⚠️ Do NOT close this window directly! Use one of these methods:\033[0m"
echo -e "\033[1;36m1. Desktop menu: System menu → Shutdown"
echo -e "2. Terminal command: sudo poweroff\033[0m\n"

# 设置环境变量
export XDG_RUNTIME_DIR=/run/user/\$(id -u)
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$(id -u)/bus

# Deepin桌面特殊修复
if [ "$DESKTOP_NAME" = "Deepin" ]; then
    # 修复背光控制器错误
    sudo mkdir -p /sys/class/backlight/dummy
    echo 100 | sudo tee /sys/class/backlight/dummy/brightness >/dev/null 2>&1
    
    # 修复显卡模式检测错误
    export DDE_DISABLE_GPU_CHECK=1
    
    # 修复用户ID 0未登录错误
    sudo loginctl enable-linger \$(id -u)
    
    # 修复显示器名称错误
    export DDE_DISABLE_DISPLAY_NAME_CHECK=1
    
    # 修复触摸屏映射错误
    export DDE_DISABLE_TOUCHSCREEN_MAPPING=1
    
    # 修复内置屏幕检测错误
    export DDE_DISABLE_BUILTIN_SCREEN_CHECK=1
    
    # 修复redshift服务错误
    export DDE_DISABLE_REDSHIFT=1
    
    # 确保正确的权限
    sudo chown -R \$(id -u):\$(id -g) ~/.config
fi

# 启动桌面环境
echo "Launching $DESKTOP_NAME desktop..."
$DESKTOP_LAUNCH

# 桌面退出后清理
echo "Desktop session ended. Cleaning up..."
systemctl restart user@\$(id -u).service
EOF

sudo chmod +x /usr/local/bin/wslg-desktop

# 12. 创建桌面启动器
echo "Creating desktop launcher..."
sudo tee /usr/share/applications/wslg-desktop.desktop >/dev/null <<EOF
[Desktop Entry]
Name=WSLg Desktop
Comment=Launch WSLg Desktop Environment
Exec=/usr/local/bin/wslg-desktop
Icon=distributor-logo
Terminal=false
Type=Application
Categories=Utility;
EOF

# 13. 创建Windows快捷方式
echo "Creating Windows shortcut..."
cat > /mnt/c/Users/Public/Desktop/WSLg-Desktop.lnk <<EOF
[Shell]
Command=2
IconFile=C:\\Windows\\System32\\wsl.exe
[Taskbar]
Command=ToggleDesktop
[InternetShortcut]
URL=https://github.com/lsl330/wslg-ubuntu
IDList=
IconIndex=0
EOF

# 14. 创建无需sudo的启动脚本
echo "Creating user-level launcher..."
tee ~/start-desktop.sh >/dev/null <<EOF
#!/bin/bash

# 确保以当前用户运行
if [ "\$(id -u)" -eq 0 ]; then
    echo "Error: This script must be run as regular user, not root."
    exit 1
fi

# 启动桌面
/usr/local/bin/wslg-desktop
EOF

chmod +x ~/start-desktop.sh

# 15. 完成提示
echo -e "\n\033[1;32m✅ Installation complete! Follow these steps:\033[0m"
echo -e "1. \033[1;34mRestart WSL: wsl --shutdown (in Windows PowerShell/CMD)\033[0m"
echo -e "2. \033[1;34mRestart your WSL Ubuntu session\033[0m"

if [ "$desktop_choice" == "3" ]; then
    echo -e "\n\033[1;33mDeepin Desktop Startup Instructions:\033[0m"
    echo -e "3. \033[1;34mStart desktop: ~/start-desktop.sh\033[0m"
    echo -e "   - Do NOT use sudo or root user"
    echo -e "   - First launch may take 1-3 minutes to initialize"
    echo -e "   - After login, set your language in Deepin Control Center:"
    echo -e "     System Settings → Personalization → Language"
    echo -e "\n\033[1;33mKnown Deepin Fixes Applied:\033[0m"
    echo -e "   - Backlight controller dummy created"
    echo -e "   - GPU checking disabled"
    echo -e "   - User linger enabled"
    echo -e "   - Display name checking disabled"
    echo -e "   - Touchscreen mapping disabled"
    echo -e "   - Built-in screen checking disabled"
    echo -e "   - Redshift service disabled"
else
    echo -e "3. \033[1;34mStart desktop: wslg-desktop\033[0m"
    echo -e "   - First launch may take 30-60 seconds to initialize"
fi

echo -e "\n\033[1;33mDesktop Launch Options:\033[0m"
echo -e "   - Command line: ~/start-desktop.sh (Deepin) or wslg-desktop (others)"
echo -e "   - Windows shortcut: Desktop 'WSLg Desktop' icon"
echo -e "   - Windows Start Menu: Search for 'WSLg Desktop'"
echo -e "\n\033[1;33mTroubleshooting:\033[0m"
echo -e "   If desktop doesn't appear, check logs:"
echo -e "      journalctl -b --user --no-pager -u user@$(id -u).service"
