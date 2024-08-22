#!/bin/bash

# 一键安装VNC和Chrome脚本
# 支持x86_64和ARM架构

# 默认VNC端口
DEFAULT_PORT=2828

# 检查用户输入的端口
read -p "请输入VNC端口号（默认: $DEFAULT_PORT）: " PORT
PORT=${PORT:-$DEFAULT_PORT}

echo "使用端口: $PORT"

# 更新系统并安装必要的软件包
sudo apt update && sudo apt upgrade -y
sudo apt install -y wget curl gnupg2 software-properties-common xvfb x11vnc websockify python3-pip

# 安装Google Chrome
if [[ $(uname -m) == 'x86_64' ]]; then
    # x86_64架构
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    sudo apt install -y ./google-chrome-stable_current_amd64.deb
elif [[ $(uname -m) == 'aarch64' ]]; then
    # ARM架构
    wget https://github.com/waveform80/chromium-binaries/raw/master/chromium-browser-stable_92.0.4515.107-1_arm64.deb
    sudo apt install -y ./chromium-browser-stable_92.0.4515.107-1_arm64.deb
else
    echo "Unsupported architecture: $(uname -m)"
    exit 1
fi

# 安装noVNC
sudo pip3 install numpy
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
websockify --web ~/noVNC --wrap-mode=ignore $PORT localhost:$PORT
EOF

# 让脚本可执行
chmod +x ~/vnc-server/start-vnc.sh

# 提示完成并启动VNC
echo "VNC安装完成。启动命令: ~/vnc-server/start-vnc.sh"
~/vnc-server/start-vnc.sh

echo "VNC已启动。您可以通过浏览器访问 http://<VPS_IP>:$PORT/vnc.html 或使用VNC客户端连接到 <VPS_IP>:$PORT。"