#!/bin/bash
# WSLg XWayland 一键部署脚本 - Ubuntu 24.04
# 功能：自动安装配置Xfce桌面环境，创建xubuntu启动命令
# 使用方法：在WSL终端中运行 ./wslg-ubuntu.sh

set -e  # 任何命令失败时退出脚本

echo "=== 开始配置 WSLg XWayland 桌面环境 ==="

# 1. 更新系统
echo "更新系统包列表和已安装的包..."
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y

# 2. 配置wsl.conf启用systemd
echo "配置wsl.conf启用systemd..."
if [ ! -f /etc/wsl.conf ]; then
    sudo touch /etc/wsl.conf
fi

if ! grep -q "systemd=true" /etc/wsl.conf; then
    sudo tee -a /etc/wsl.conf > /dev/null <<EOF
[boot]
systemd=true
EOF
fi

# 3. 安装Xfce桌面环境和必要组件
echo "安装Xubuntu桌面环境和必要组件..."
sudo DEBIAN_FRONTEND=noninteractive apt install -y \
    xubuntu-desktop \
    xwayland \
    dbus-x11 \
    systemd

# 4. 创建wslg-fix服务
echo "创建并启用wslg-fix服务..."
sudo tee /etc/systemd/system/wslg-fix.service > /dev/null <<EOF
[Unit]
Description=Fix WSLg directory permissions

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

# 5. 修改user-runtime服务
echo "修改user-runtime服务配置..."
sudo mkdir -p /etc/systemd/system/user-runtime-dir@.service.d
sudo tee /etc/systemd/system/user-runtime-dir@.service.d/override.conf > /dev/null <<EOF
[Service]
ExecStartPost=-/usr/bin/rm -f /run/user/%i/wayland-0 /run/user/%i/wayland-0.lock
EOF

# 6. 设置默认启动目标
echo "设置默认启动目标..."
sudo systemctl set-default multi-user.target

# 7. 配置XWayland替换Xorg
echo "配置XWayland替换默认Xorg..."
sudo mv /usr/bin/Xorg /usr/bin/Xorg.original 2>/dev/null || true

sudo tee /usr/bin/Xorg.Xwayland > /dev/null <<'EOF'
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

command=("/usr/bin/Xwayland" ":${displayNumber}" "-geometry" "1920x1080" "-fullscreen" "$@")

systemd-cat -t /usr/bin/Xorg echo "Starting Xwayland:" "${command[@]}"

exec "${command[@]}"
EOF

sudo chmod 0755 /usr/bin/Xorg.Xwayland
sudo ln -sf Xorg.Xwayland /usr/bin/Xorg

# 8. 配置显示器分辨率
echo "配置显示器分辨率..."
mkdir -p ~/.config
tee ~/.config/monitors.xml > /dev/null <<'EOF'
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

# 9. 创建桌面启动命令
echo "创建桌面启动命令..."
sudo tee /usr/local/bin/xubuntu > /dev/null <<'EOF'
#!/bin/bash
# 启动Xfce桌面环境
sudo systemctl start graphical.target

# 等待桌面启动
sleep 3

# 检查桌面状态
if systemctl is-active -q graphical.target; then
    echo "Xfce桌面已启动成功!"
    echo "提示: 要关闭桌面，请在桌面中使用系统菜单关机或执行: sudo poweroff"
else
    echo "桌面启动失败，请检查日志: journalctl -b -t /usr/bin/Xorg"
fi
EOF

sudo chmod +x /usr/local/bin/xubuntu

# 10. 完成提示
echo -e "\n=== 安装完成! ==="
echo "请按以下步骤操作:"
echo "1. 关闭当前WSL终端"
echo "2. 在PowerShell中运行: wsl --shutdown"
echo "3. 重新打开Ubuntu WSL终端"
echo "4. 输入命令: xubuntu"
echo "5. 稍等片刻(首次启动可能需要30秒)，Xfce桌面将会出现"
echo "6. 使用你的WSL用户名和密码登录"

echo -e "\n注意: 关闭桌面环境时，请使用桌面系统菜单的关机选项或运行: sudo poweroff"
