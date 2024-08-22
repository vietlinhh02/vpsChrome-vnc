#!/bin/bash

# 一键安装VNC和Chrome脚本
# 支持x86_64和ARM架构

# 默认VNC端口
DEFAULT_PORT=2828

# 检查用户输入的端口
read -p "请输入VNC端口号（默认: $DEFAULT_PORT，直接输入端口号则VNC和noVNC统一端口，输入1分别修改端口，回车使用默认端口）： " PORT

if [ "$PORT" = "" ]; then
    PORT=$DEFAULT_PORT
    NOVNC_PORT=$DEFAULT_PORT
elif [ "$PORT" = "1" ]; then
    read -p "请输入VNC端口号： " VNC_PORT
    read -p "请输入noVNC端口号： " NOVNC_PORT
    PORT=$VNC_PORT
else
    NOVNC_PORT=$PORT
fi

echo "使用端口: $PORT"

# 更新系统并安装必要的软件包
sudo apt update && sudo apt upgrade -y
sudo apt install -y wget curl gnupg2 software-properties-common xvfb x11vnc websockify python3-pip

# 安装Google Chrome
case $(uname -m) in
    x86_64)
        # x86_64架构
        wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
        ;;
    aarch64)
        # ARM架构
        wget https://github.com/waveform80/chromium-binaries/raw/master/chromium-browser-stable_92.0.4515.107-1_arm64.deb
        ;;
    *)
        echo "Unsupported architecture: $(uname -m)"
        exit 1
        ;;
esac

# 安装软件包
if! sudo apt install -y./google-chrome-stable_current_amd64.deb; then
    echo "安装Google Chrome失败，请检查网络连接和软件包源。"
    exit 1
fi

# 安装noVNC
if! sudo pip3 install numpy; then
    echo "安装noVNC失败，请检查网络连接和软件包源。"
    exit 1
fi

wget https://github.com/novnc/noVNC/archive/refs/tags/v1.3.0.tar.gz
tar -xzf v1.3.0.tar.gz
mv noVNC-1.3.0 ~/noVNC

# 创建VNC启动脚本
mkdir -p ~/vnc-server
cat << EOF > ~/vnc-server/start-vnc.sh
#!/bin/bash
Xvfb :99 -screen 0 1280x800x24 &
export DISPLAY=:99
google-chrome --no-sandbox --disable-gpu --remote-debugging-port=9222 --no-first-run --disable-translate --user-data-dir=/tmp/chrome &
x11vnc -display :99 -nopw -forever -shared -rfbport $PORT &
websockify --web ~/noVNC --wrap-mode=ignore $NOVNC_PORT localhost:$NOVNC_PORT
EOF

# 让脚本可执行
chmod +x ~/vnc-server/start-vnc.sh

# 添加系统服务
sudo cat << EOF > /etc/systemd/system/vnc.service
[Unit]
Description=VNC Server
After=network.target

[Service]
User=$USER
ExecStart=/home/$USER/vnc-server/start-vnc.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 启用系统服务
if! sudo systemctl enable vnc; then
    echo "启用VNC服务失败，请检查系统服务配置。"
    exit 1
fi

if! sudo systemctl start vnc; then
    echo "启动VNC服务失败，请检查系统服务配置。"
    exit 1
fi

# 获取公网IP地址
IP=$(curl -s -4 icanhazip.com)
if [ -z "$IP" ]; then
    IP="127.0.0.1"
fi

# 提示完成并启动VNC
echo "VNC安装完成。启动命令: vchrome"
echo "您可以通过浏览器访问 http://$IP:$NOVNC_PORT/vnc.html 或使用VNC客户端连接到 $IP:$PORT。"

# 显示帮助信息
echo "使用方法："
echo "  vchrome -i   显示VNC和Chrome版本信息"
echo "  vchrome -u   升级VNC和Chrome"
echo "  vchrome -r   卸载VNC和Chrome"

# 处理命令行参数
if [ "$1" = "-h" ] || [ "$1" = "--help
