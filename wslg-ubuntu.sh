#!/bin/bash
# WSLg Xfce 桌面环境一键部署脚本 - Ubuntu 24.04
# 功能：自动安装配置Xfce桌面环境，创建xubuntu启动命令
# 版本：v1.1 - 添加plocate卡死修复

set -e  # 任何命令失败时退出脚本

echo "=== 开始配置 WSLg Xfce 桌面环境 ==="

# 1. 更新系统
echo "更新系统包列表和已安装的包..."
sudo apt update -y > /dev/null
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y > /dev/null

# 2. 配置wsl.conf启用systemd
echo "配置wsl.conf启用systemd..."
sudo tee /etc/wsl.conf > /dev/null <<EOF
[boot]
systemd=true
[automount]
options = "metadata,uid=1000,gid=1000,umask=22,fmask=11"
EOF

# 3. 预先配置plocate避免卡死
echo "配置plocate跳过/mnt目录索引..."
sudo tee /etc/updatedb.conf > /dev/null <<'EOF'
PRUNE_BIND_MOUNTS="yes"
PRUNENAMES=".git .bzr .hg .svn"
PRUNEPATHS="/tmp /var/spool /var/lock /var/cache /var/lib/lxcfs /var/lib/docker /mnt"
PRUNEFS="NFS nfs nfs4 rpc_pipefs afs binfmt_misc proc smbfs autofs iso9660 ncpfs coda devpts ftpfs devfs mfs shfs sysfs cifs lustre_lite tmpfs usbfs udf fuse.glusterfs fuse.sshfs curlftpfs ecryptfs fusesmb devtmpfs"
EOF

# 4. 安装Xfce桌面环境和必要组件
echo "安装Xubuntu桌面环境和必要组件..."
sudo DEBIAN_FRONTEND=noninteractive apt install -y \
    xubuntu-desktop \
    xwayland \
    dbus-x11 \
    systemd > /dev/null

# 5. 修复plocate数据库（快速初始化）
echo "初始化plocate数据库（快速完成）..."
sudo updatedb > /dev/null 2>&1

# 6. 创建wslg-fix服务
echo "创建并启用wslg-fix服务..."
sudo tee /etc/systemd/system/wslg-fix.service > /dev/null <<'EOF'
[Unit]
Description=Fix WSLg directory permissions
After=systemd-remount-fs.service

[Service]
Type=oneshot
ExecStart=-/usr/bin/umount /tmp/.X11-unix
ExecStart=/usr/bin/rm -rf /tmp/.X11-unix
ExecStart=/usr/bin/mkdir -p /tmp/.X11-unix
ExecStart=/usr/bin/chmod 1777 /tmp/.X11-unix
ExecStart=/usr/bin/ln -fs /mnt/wslg/.X11-unix/X0 /tmp/.X11-unix/X0
ExecStart=/usr/bin/chmod 0777 /mnt/wslg/runtime-dir
ExecStart=/usr/bin/chmod 0666 /mnt/wslg/runtime-dir/wayland-0.lock

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable wslg-fix.service > /dev/null

# 7. 修改user-runtime服务
echo "修改user-runtime服务配置..."
sudo mkdir -p /etc/systemd/system/user-runtime-dir@.service.d
sudo tee /etc/systemd/system/user-runtime-dir@.service.d/override.conf > /dev/null <<'EOF'
[Service]
ExecStartPost=-/usr/bin/rm -f /run/user/%i/wayland-0 /run/user/%i/wayland-0.lock
EOF

# 8. 设置默认启动目标
echo "设置默认启动目标..."
sudo systemctl set-default multi-user.target > /dev/null

# 9. 配置XWayland替换Xorg
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
 mkdir -p $HOME/runtime-dir
 ln -fs /mnt/wslg/runtime-dir/wayland-0 /mnt/wslg/runtime-dir/wayland-0.lock $HOME/runtime-dir/
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

# 10. 配置显示器分辨率
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

# 11. 创建桌面启动命令
echo "创建桌面启动命令..."
sudo tee /usr/local/bin/xubuntu > /dev/null <<'EOF'
#!/bin/bash
# 启动Xfce桌面环境
sudo systemctl start graphical.target > /dev/null 2>&1

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

# 12. 清理缓存
echo "清理系统缓存..."
sudo apt autoremove -y > /dev/null
sudo apt clean > /dev/null

# 13. 完成提示
cat <<EOF

=== 🎉 安装完成! ===

请按以下步骤操作:
1. 关闭当前WSL终端
2. 在PowerShell中运行: wsl --shutdown
3. 重新打开Ubuntu WSL终端
4. 输入命令: xubuntu
5. 稍等片刻(首次启动可能需要30秒)，Xfce桌面将会出现
6. 使用你的WSL用户名和密码登录

注意: 关闭桌面环境时，请务必使用以下方式之一:
   - 桌面系统菜单的关机选项
   - 在终端执行: sudo poweroff

❌ 切勿直接关闭终端窗口! 否则可能导致文件系统损坏!
EOF

# 添加关机提醒到.bashrc
if ! grep -q "安全关机提醒" ~/.bashrc; then
    tee -a ~/.bashrc > /dev/null <<'EOF'

# 安全关机提醒
echo -e "\e[31m重要提示: 使用完桌面后，请通过系统菜单关机或执行 'sudo poweroff' 命令安全关闭系统\e[0m"
echo -e "\e[31m切勿直接关闭终端窗口，否则可能导致文件损坏!\e[0m"
EOF
fi
