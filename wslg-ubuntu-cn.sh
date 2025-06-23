#!/bin/bash

# WSL Ubuntu Desktop Installer with WSLg Support (中文版)
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

# 0. 安装中文语言支持
echo "安装中文语言支持..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    language-pack-zh-hans \
    language-pack-gnome-zh-hans \
    fonts-noto-cjk \
    fonts-noto-ui-core \
    fonts-arphic-uming \
    fonts-arphic-ukai

# 配置中文环境变量
echo "配置中文环境变量..."
sudo tee -a /etc/environment >/dev/null <<EOF
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_CTYPE="zh_CN.UTF-8"
LC_NUMERIC="zh_CN.UTF-8"
LC_TIME="zh_CN.UTF-8"
LC_COLLATE="zh_CN.UTF-8"
LC_MONETARY="zh_CN.UTF-8"
LC_MESSAGES="zh_CN.UTF-8"
LC_PAPER="zh_CN.UTF-8"
LC_NAME="zh_CN.UTF-8"
LC_ADDRESS="zh_CN.UTF-8"
LC_TELEPHONE="zh_CN.UTF-8"
LC_MEASUREMENT="zh_CN.UTF-8"
LC_IDENTIFICATION="zh_CN.UTF-8"
LC_ALL=zh_CN.UTF-8
EOF

# 配置本地化
sudo locale-gen zh_CN.UTF-8
sudo update-locale LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8

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

# 3. 安装Ubuntu GNOME桌面环境
echo "安装Ubuntu GNOME桌面环境 (约2GB，请耐心等待)..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ubuntu-desktop \
    xwayland \
    dbus-x11 \
    policykit-1-gnome

# 4. 创建wslg-fix服务 (关键修复)
echo "创建wslg-fix服务..."
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

# 5. 修复Wayland引用问题
echo "修复Wayland引用问题..."
sudo mkdir -p /etc/systemd/system/user-runtime-dir@.service.d/
sudo tee /etc/systemd/system/user-runtime-dir@.service.d/override.conf >/dev/null <<'EOF'
[Service]
ExecStartPost=-/usr/bin/rm -f /run/user/%i/wayland-0 /run/user/%i/wayland-0.lock
EOF

# 6. 替换Xorg为Xwayland脚本 (关键修复)
echo "替换Xorg为Xwayland脚本..."
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
sudo ln -sf /usr/bin/Xorg.Xwayland /usr/bin/Xorg

# 7. 配置显示目标
echo "配置显示目标..."
sudo systemctl set-default multi-user.target

# 8. 手动安全初始化plocate
echo "安全初始化plocate数据库..."
sudo mkdir -p /var/lib/plocate
sudo updatedb --require-visibility 0 2>/dev/null || true
echo "plocate数据库初始化完成"

# 9. 修复WSLg权限问题
echo "修复WSLg目录权限..."
sudo chmod 1777 /tmp
[ -d /usr/share/desktop-directories ] && sudo chmod 1777 /usr/share/desktop-directories || true

# 10. 设置分辨率配置
echo "配置默认分辨率1920x1080..."
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

# 为GDM用户复制配置文件
sudo mkdir -p /var/lib/gdm3/.config
sudo cp ~/.config/monitors.xml /var/lib/gdm3/.config/ || true
sudo chown -R gdm:gdm /var/lib/gdm3/.config/ || true

# 11. 设置中文输入法
echo "设置中文输入法..."
sudo apt-get install -y fcitx fcitx-googlepinyin fcitx-config-gtk
tee -a ~/.profile >/dev/null <<'EOF'
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
EOF

# 12. 创建启动脚本
echo "创建启动脚本..."
sudo tee /usr/local/bin/ubuntu-desktop >/dev/null <<'EOF'
#!/bin/bash

# 显示关机提示
echo -e "\n\033[1;33m⚠️ 请勿直接关闭窗口! 请使用以下方式关机:\033[0m"
echo -e "\033[1;36m1. 桌面菜单: 右上角系统菜单 → 关机"
echo -e "2. 终端命令: sudo poweroff\033[0m\n"

# 启动图形目标
echo "启动图形界面..."
sudo systemctl start graphical.target

# 等待桌面启动
echo "等待桌面环境启动 (首次启动需30-60秒)..."
sleep 15

# 如果使用GDM，显示登录状态
if systemctl is-active --quiet gdm3; then
    echo "GDM登录界面应该已显示，请使用Windows的WSLg窗口查看"
    echo "首次登录后可能需要设置区域语言为中文（中国）"
fi
EOF

sudo chmod +x /usr/local/bin/ubuntu-desktop

# 13. 完成提示
echo -e "\n\033[1;32m✅ 安装完成！请按以下步骤操作："
echo -e "1. 重启WSL: 在Windows终端执行: wsl --shutdown"
echo -e "2. 重新启动WSL后，输入命令: ubuntu-desktop"
echo -e "3. 首次启动需要30-60秒初始化，请耐心等待"
echo -e "4. 在登录界面右上角选择语言为 '中文（中国）'"
echo -e "5. 登录后可能需要设置用户语言为中文（系统会自动提示）\033[0m"
echo -e "\n\033[1;33m注意：如果桌面未显示，请检查日志: journalctl -b -t /usr/lib/gdm3/gdm-x-session -t /usr/bin/Xorg --no-pager\033[0m"
