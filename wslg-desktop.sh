# 在 init_resolution 函数中添加
init_resolution() {
    msg init_resolution
    
    # ... [之前的代码保持不变] ...
    
    # 创建缩放配置文件
    cat > ~/.config/scale <<EOF
#!/bin/sh
# 禁用自动缩放
gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"
gsettings set org.gnome.mutter experimental-features "['x11-randr-fractional-scaling']"

# 设置缩放为100%
gsettings reset org.gnome.desktop.interface scaling-factor
gsettings reset org.gnome.desktop.interface text-scaling-factor
gsettings set org.gnome.desktop.interface scaling-factor 1
gsettings set org.gnome.settings-daemon.plugins.xsettings overrides "[{'Gdk/WindowScalingFactor', <2>}]"

# 应用自定义分辨率
xrandr --output XWAYLAND0 --mode ${RES_WIDTH}x${RES_HEIGHT}
EOF
    
    chmod +x ~/.config/scale
    
    # 为GDM用户复制配置文件
    sudo cp ~/.config/scale /var/lib/gdm3/.config/ || true
    sudo chown gdm:gdm /var/lib/gdm3/.config/scale || true
}

# 修改 wslg-desktop 启动脚本
sudo tee /usr/local/bin/wslg-desktop >/dev/null <<'EOF'
#!/bin/bash

# ... [之前的代码保持不变] ...

# 启动图形目标
echo "Starting graphical session..."
sudo systemctl start graphical.target
sleep 2 # 等待系统服务启动

# 应用缩放设置
if [ -f ~/.config/scale ]; then
    ~/.config/scale
fi

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
