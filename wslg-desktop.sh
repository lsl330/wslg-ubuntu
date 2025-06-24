#!/bin/bash

# WSL Multi-Desktop Installer with WSLg Support
# GitHub: https://github.com/lsl330/wslg-ubuntu

set -e

# 检测用户语言
USER_LANG=$(echo $LANG | cut -d'.' -f1)
if [[ $USER_LANG == "zh_CN" || $USER_LANG == "zh_TW" ]]; then
    USE_CHINESE=true
else
    USE_CHINESE=false
fi

# 多语言显示函数
msg() {
    if [ "${USE_CHINESE}" = true ]; then
        case "$1" in
            "enable_systemd") echo "启用systemd支持..." ;;
            "update_system") echo "更新系统包列表..." ;;
            "install_lang_pack") echo "安装语言支持..." ;;
            "config_lang") echo "配置语言环境..." ;;
            "create_plocate_conf") echo "创建plocate配置文件..." ;;
            "disable_plocate_script") echo "禁用plocate安装后脚本..." ;;
            "install_desktop") echo "安装桌面环境 (请耐心等待)..." ;;
            "create_wslg_fix") echo "创建wslg-fix服务..." ;;
            "fix_wayland") echo "修复Wayland引用问题..." ;;
            "replace_xorg") echo "替换Xorg为Xwayland脚本..." ;;
            "set_display_target") echo "配置显示目标..." ;;
            "init_plocate") echo "安全初始化plocate数据库..." ;;
            "fix_permissions") echo "修复WSLg目录权限..." ;;
            "create_launcher") echo "创建启动脚本..." ;;
            "create_desktop_file") echo "创建桌面快捷方式..." ;;
            "init_resolution") echo "初始化分辨率配置..." ;;
            "install_complete") 
                echo -e "\n\033[1;32m✅ 安装完成！请按以下步骤操作："
                echo -e "1. 重启WSL: 在Windows终端执行: wsl --shutdown"
                echo -e "2. 重新启动WSL后，输入命令: wslg-desktop"
                echo -e "3. 首次启动需要30-60秒初始化，请耐心等待"
                echo -e "4. 桌面关闭后重新进入请再次运行: wslg-desktop\033[0m"
                ;;
            "shutdown_prompt")
                echo -e "\n\033[1;33m⚠️ 请勿直接关闭窗口! 请使用正确方式关机:\033[0m"
                echo -e "\033[1;36m1. 桌面菜单: 系统菜单 → 关机"
                echo -e "2. 终端命令: sudo poweroff\033[0m\n"
                ;;
            "resolution_fallback")
                echo -e "\033[1;33m无法获取当前分辨率，使用默认值1920x1080\033[0m"
                ;;
        esac
    else
        case "$1" in
            "enable_systemd") echo "Enabling systemd support..." ;;
            "update_system") echo "Updating package lists..." ;;
            "install_lang_pack") echo "Installing language support..." ;;
            "config_lang") echo "Configuring language environment..." ;;
            "create_plocate_conf") echo "Creating plocate configuration..." ;;
            "disable_plocate_script") echo "Disabling plocate post-install script..." ;;
            "install_desktop") echo "Installing desktop environment (please wait)..." ;;
            "create_wslg_fix") echo "Creating wslg-fix service..." ;;
            "fix_wayland") echo "Fixing Wayland references..." ;;
            "replace_xorg") echo "Replacing Xorg with Xwayland script..." ;;
            "set_display_target") echo "Setting display target..." ;;
            "init_plocate") echo "Initializing plocate database safely..." ;;
            "fix_permissions") echo "Fixing WSLg permissions..." ;;
            "create_launcher") echo "Creating launcher script..." ;;
            "create_desktop_file") echo "Creating desktop shortcut..." ;;
            "init_resolution") echo "Initializing resolution configuration..." ;;
            "install_complete")
                echo -e "\n\033[1;32m✅ Installation complete! Please follow these steps:"
                echo -e "1. Reboot WSL: In Windows terminal run: wsl --shutdown"
                echo -e "2. After WSL restarts, run: wslg-desktop"
                echo -e "3. First launch may take 30-60 seconds"
                echo -e "4. To relaunch desktop after closing, run: wslg-desktop again\033[0m"
                ;;
            "shutdown_prompt")
                echo -e "\n\033[1;33m⚠️ Do not close the window directly! Proper shutdown methods:\033[0m"
                echo -e "\033[1;36m1. Desktop menu: System → Shutdown"
                echo -e "2. Terminal command: sudo poweroff\033[0m\n"
                ;;
            "resolution_fallback")
                echo -e "\033[1;33mUnable to detect resolution, using default 1920x1080\033[0m"
                ;;
        esac
    fi
}

# 选择语言
select_language() {
    PS3="$(if [ "${USE_CHINESE}" = true ]; then 
        echo "请选择系统语言: "; 
    else 
        echo "Select system language: "; 
    fi)"
    
    options=("English" "简体中文" "繁體中文" "日本語")
    select lng in "${options[@]}"
    do
        case $lng in
            "English")
                LANG_CODE="en_US.UTF-8"
                break
                ;;
            "简体中文")
                LANG_CODE="zh_CN.UTF-8"
                break
                ;;
            "繁體中文")
                LANG_CODE="zh_TW.UTF-8"
                break
                ;;
            "日本語")
                LANG_CODE="ja_JP.UTF-8"
                break
                ;;
            *) 
                if [ "${USE_CHINESE}" = true ]; then 
                    echo "无效选项，请重新选择"; 
                else 
                    echo "Invalid option, try again"; 
                fi
                ;;
        esac
    done
}

# 选择桌面环境
select_desktop() {
    PS3="$(if [ "${USE_CHINESE}" = true ]; then 
        echo "请选择桌面环境: "; 
    else 
        echo "Select desktop environment: "; 
    fi)"
    
    options=("GNOME (完整桌面)" "Xfce (轻量级桌面)")
    select desktop in "${options[@]}"
    do
        case $desktop in
            "GNOME (完整桌面)")
                DESKTOP_ENV="gnome"
                break
                ;;
            "Xfce (轻量级桌面)")
                DESKTOP_ENV="xfce"
                break
                ;;
            *) 
                if [ "${USE_CHINESE}" = true ]; then 
                    echo "无效选项，请重新选择"; 
                else 
                    echo "Invalid option, try again"; 
                fi
                ;;
        esac
    done
}

# 初始化分辨率配置
init_resolution() {
    msg init_resolution
    
    # 默认分辨率
    RES_WIDTH=1920
    RES_HEIGHT=1080
    
    # 使用wmic获取当前分辨率，awk输出格式为 "宽度x高度"
    RESOLUTION=$(powershell.exe -Command "wmic path Win32_VideoController get CurrentHorizontalResolution,CurrentVerticalResolution" | awk 'NR==2 {print $1 "x" $2}')

    # 使用 cut 命令分割字符串
    # -d 'x' 指定分隔符为 'x'
    # -f 1 获取第一个字段 (宽度)
    # -f 2 获取第二个字段 (高度)
    RES_WIDTH=$(echo "$RESOLUTION" | cut -dx -f 1)
    RES_HEIGHT=$(echo "$RESOLUTION" | cut -dx -f 2)

    # 检查是否成功获取了数字
    if [[ "$RES_WIDTH" =~ ^[0-9]+$ ]] && [[ "$RES_HEIGHT" =~ ^[0-9]+$ ]]; then
        echo "通过WMIC检测到分辨率: ${RES_WIDTH}x${RES_HEIGHT}"
    else
        msg resolution_fallback
    fi
    
    # 创建分辨率配置文件
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
          <width>${RES_WIDTH}</width>
          <height>${RES_HEIGHT}</height>
          <rate>59.963</rate>
        </mode>
      </monitor>
    </logicalmonitor>
  </configuration>
</monitors>
EOF
    
    # 为GDM用户复制配置文件
    sudo mkdir -p /var/lib/gdm3/.config
    sudo cp ~/.config/monitors.xml /var/lib/gdm3/.config/ || true
    sudo chown -R gdm:gdm /var/lib/gdm3/.config/ || true
    
    # 在Xwayland脚本中硬编码分辨率
    sudo sed -i "s/-geometry [0-9]\+x[0-9]\+/-geometry ${RES_WIDTH}x${RES_HEIGHT}/" /usr/bin/Xorg.Xwayland
}

# 主安装程序
main() {
    # 用户选择
    select_language
    select_desktop
    
    # 保存桌面环境配置
    echo "DESKTOP_ENV=$DESKTOP_ENV" | sudo tee /etc/wslg-desktop-env >/dev/null
    
    # 启用systemd
    msg enable_systemd
    sudo tee /etc/wsl.conf >/dev/null <<EOF
[boot]
systemd=true
EOF

    # 更新系统
    msg update_system
    sudo apt-get update
    sudo apt-get upgrade -y

    # 初始化分辨率配置
    init_resolution

    # 安装语言支持
    msg install_lang_pack
    case $LANG_CODE in
        "zh_CN.UTF-8")
            sudo apt-get install -y language-pack-zh-hans language-pack-gnome-zh-hans
            ;;
        "zh_TW.UTF-8")
            sudo apt-get install -y language-pack-zh-hant language-pack-gnome-zh-hant
            ;;
        "ja_JP.UTF-8")
            sudo apt-get install -y language-pack-ja language-pack-gnome-ja
            ;;
        *)
            sudo apt-get install -y language-pack-en language-pack-gnome-en
            ;;
    esac

    # 通用字体安装
    sudo apt-get install -y fonts-noto-cjk fonts-noto-ui-core

    # 配置语言环境
    msg config_lang
    sudo tee /etc/default/locale >/dev/null <<EOF
LANG="$LANG_CODE"
LANGUAGE="${LANG_CODE%.*}:en_US:en"
EOF
    sudo update-locale LANG="$LANG_CODE" LC_ALL="$LANG_CODE"

    # 创建plocate配置
    msg create_plocate_conf
    sudo tee /etc/updatedb.conf >/dev/null <<'EOF'
PRUNE_BIND_MOUNTS="yes"
PRUNENAMES=".git .bzr .hg .svn"
PRUNEPATHS="/tmp /var/spool /var/lock /var/cache /var/lib/lxcfs /var/lib/docker /mnt"
PRUNEFS="NFS nfs nfs4 rpc_pipefs afs binfmt_misc proc smbfs autofs iso9660 ncpfs coda devpts ftpfs devfs mfs shfs sysfs cifs lustre_lite tmpfs usbfs udf fuse.glusterfs fuse.sshfs curlftpfs ecryptfs fusesmb devtmpfs"
EOF

    # 禁用plocate安装后脚本
    msg disable_plocate_script
    sudo mkdir -p /var/lib/dpkg/info/
    sudo tee /var/lib/dpkg/info/plocate.postinst >/dev/null <<'EOF'
#!/bin/sh
set -e
echo "Skipping plocate database initialization (pre-configured for WSL)"
exit 0
EOF
    sudo chmod 0755 /var/lib/dpkg/info/plocate.postinst

    # 安装桌面环境
    msg install_desktop
    sudo apt-get install -y xwayland dbus-x11 policykit-1-gnome
    
    if [ "$DESKTOP_ENV" = "gnome" ]; then
        sudo apt-get install -y ubuntu-desktop
        DESKTOP_NAME="Ubuntu Desktop"
        DESKTOP_EXEC="gnome-session"
    else
        sudo apt-get install -y xubuntu-desktop
        DESKTOP_NAME="Xubuntu Desktop"
        DESKTOP_EXEC="startxfce4"
    fi

    # 创建wslg-fix服务
    msg create_wslg_fix
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

    # 修复Wayland引用
    msg fix_wayland
    sudo mkdir -p /etc/systemd/system/user-runtime-dir@.service.d/
    sudo tee /etc/systemd/system/user-runtime-dir@.service.d/override.conf >/dev/null <<'EOF'
[Service]
ExecStartPost=-/usr/bin/rm -f /run/user/%i/wayland-0 /run/user/%i/wayland-0.lock
EOF

    # 替换Xorg为Xwayland
    msg replace_xorg
    sudo mv /usr/bin/Xorg /usr/bin/Xorg.original 2>/dev/null || true
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
 ln -s /mnt/wslg/runtime-dir/wayland-0 /mnt/wslg/runtime-dir/wayland-0.lock $HOME/runtime-dir/
fi

export XDG_RUNTIME_DIR=$HOME/runtime-dir

for displayNumber in $(seq 1 100)
do
  [ ! -e /tmp/.X11-unix/X$displayNumber ] && break
done

command=("/usr/bin/Xwayland" ":${displayNumber}" "-geometry" "${RES_WIDTH}x${RES_HEIGHT}" "-fullscreen" "$@")

systemd-cat -t /usr/bin/Xorg echo "Starting Xwayland:" "${command[@]}"

exec "${command[@]}"
EOF
    sudo chmod 0755 /usr/bin/Xorg.Xwayland
    sudo ln -sf /usr/bin/Xorg.Xwayland /usr/bin/Xorg

    # 配置显示目标
    msg set_display_target
    sudo systemctl set-default multi-user.target

    # 初始化plocate
    msg init_plocate
    sudo mkdir -p /var/lib/plocate
    sudo updatedb --require-visibility 0 2>/dev/null || true

    # 修复权限
    msg fix_permissions
    sudo chmod 1777 /tmp
    [ -d /usr/share/desktop-directories ] && sudo chmod 1777 /usr/share/desktop-directories || true

    # 创建启动脚本（解决DBUS连接问题）
    msg create_launcher
    sudo tee /usr/local/bin/wslg-desktop >/dev/null <<'EOF'
#!/bin/bash

# 加载桌面环境配置
if [ -f /etc/wslg-desktop-env ]; then
    source /etc/wslg-desktop-env
else
    DESKTOP_ENV="gnome" # 默认值
fi

# 确保必要的目录存在
mkdir -p "$HOME/runtime-dir"
ln -sf /mnt/wslg/runtime-dir/wayland-0 $HOME/runtime-dir/ || true
ln -sf /mnt/wslg/runtime-dir/wayland-0.lock $HOME/runtime-dir/ || true

# 设置环境变量
export XDG_RUNTIME_DIR="$HOME/runtime-dir"
export WAYLAND_DISPLAY="wayland-0"
export DISPLAY=":0"

# 解决DBUS连接问题
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    if [ -e "$XDG_RUNTIME_DIR/bus" ]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
    else
        # 创建DBUS会话
        dbus-run-session -- sh -c 'echo "DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS" > ~/.dbus.env'
        source ~/.dbus.env
    fi
fi

# 重置用户systemd会话
systemctl --user daemon-reload >/dev/null 2>&1
systemctl --user reset-failed >/dev/null 2>&1

# 显示关机提示
if [ -n "$(echo $LANG | grep -E 'zh_CN|zh_TW')" ]; then
    echo -e "\n\033[1;33m⚠️ 请勿直接关闭窗口! 请使用以下方式关机:\033[0m"
    echo -e "\033[1;36m1. 桌面菜单: 系统菜单 → 关机"
    echo -e "2. 终端命令: sudo poweroff\033[0m\n"
else
    echo -e "\n\033[1;33m⚠️ Do not close window directly! Proper shutdown methods:\033[0m"
    echo -e "\033[1;36m1. Desktop menu: System → Shutdown"
    echo -e "2. Terminal command: sudo poweroff\033[0m\n"
fi

# 启动图形目标
echo "Starting graphical session..."
sudo systemctl start graphical.target
sleep 2 # 等待系统服务启动

# 启动用户桌面会话
echo "Starting desktop environment: $DESKTOP_ENV"
case "$DESKTOP_ENV" in
    "gnome")
        export XDG_CURRENT_DESKTOP=ubuntu:GNOME
        exec gnome-session
        ;;
    "xfce")
        exec startxfce4
        ;;
    *)
        echo "Unknown desktop environment: $DESKTOP_ENV"
        exit 1
        ;;
esac
EOF
    sudo chmod +x /usr/local/bin/wslg-desktop

    # 创建桌面快捷方式
    msg create_desktop_file
    mkdir -p ~/.local/share/applications
    cat > ~/.local/share/applications/wslg.desktop <<EOF
[Desktop Entry]
Name=$DESKTOP_NAME
Comment=WSLg Desktop Environment
Exec=/usr/local/bin/wslg-desktop
Icon=org.gnome.Settings
Terminal=false
Type=Application
Categories=System;
EOF
    # 在Windows开始菜单创建快捷方式
    if command -v wslview >/dev/null; then
        mkdir -p "$(wslpath "$(wslvar USERPROFILE)")/AppData/Roaming/Microsoft/Windows/Start Menu/Programs"
        cp ~/.local/share/applications/wslg.desktop "$(wslpath "$(wslvar USERPROFILE)")/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/WSLg Desktop.lnk"
    fi

    # 完成提示
    msg install_complete
}

# 执行主程序
main
