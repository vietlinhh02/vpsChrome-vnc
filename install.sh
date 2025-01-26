#!/bin/bash

# One-click installation script for VNC and Chrome
# Supports x86_64 and ARM architectures

# Default VNC port
DEFAULT_PORT=2828

# Check user input for port
read -p "Enter VNC port number (default: $DEFAULT_PORT, directly enter port number to use the same port for VNC and noVNC, enter 1 to specify different ports, press Enter to use default port): " PORT

if [ "$PORT" = "" ]; then
    PORT=$DEFAULT_PORT
    NOVNC_PORT=$DEFAULT_PORT
elif [ "$PORT" = "1" ]; then
    read -p "Enter VNC port number: " VNC_PORT
    read -p "Enter noVNC port number: " NOVNC_PORT
    PORT=$VNC_PORT
else
    NOVNC_PORT=$PORT
fi

echo "Using port: $PORT"

# Update system and install necessary packages
sudo apt update && sudo apt upgrade -y
sudo apt install -y wget curl gnupg2 software-properties-common xvfb x11vnc websockify python3-pip

# Install Google Chrome
case $(uname -m) in
    x86_64)
        # x86_64 architecture
        wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
        ;;
    aarch64)
        # ARM architecture
        wget https://github.com/waveform80/chromium-binaries/raw/master/chromium-browser-stable_92.0.4515.107-1_arm64.deb
        ;;
    *)
        echo "Unsupported architecture: $(uname -m)"
        exit 1
        ;;
esac

# Install the downloaded package
if ! sudo apt install -y ./google-chrome-stable_current_amd64.deb; then
    echo "Failed to install Google Chrome. Please check your network connection and package sources."
    exit 1
fi

# Install noVNC
if ! sudo pip3 install numpy; then
    echo "Failed to install noVNC. Please check your network connection and package sources."
    exit 1
fi

wget https://github.com/novnc/noVNC/archive/refs/tags/v1.3.0.tar.gz
tar -xzf v1.3.0.tar.gz
mv noVNC-1.3.0 ~/noVNC

# Create VNC startup script
mkdir -p ~/vnc-server
cat << EOF > ~/vnc-server/start-vnc.sh
#!/bin/bash
Xvfb :99 -screen 0 1280x800x24 &
export DISPLAY=:99
google-chrome --no-sandbox --disable-gpu --remote-debugging-port=9222 --no-first-run --disable-translate --user-data-dir=/tmp/chrome &
x11vnc -display :99 -nopw -forever -shared -rfbport $PORT &
websockify --web ~/noVNC --wrap-mode=ignore $NOVNC_PORT localhost:$NOVNC_PORT
EOF

# Make the script executable
chmod +x ~/vnc-server/start-vnc.sh

# Add system service
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

# Enable system service
if ! sudo systemctl enable vnc; then
    echo "Failed to enable VNC service. Please check the system service configuration."
    exit 1
fi

if ! sudo systemctl start vnc; then
    echo "Failed to start VNC service. Please check the system service configuration."
    exit 1
fi

# Get public IP address
IP=$(curl -s -4 icanhazip.com)
if [ -z "$IP" ]; then
    IP="127.0.0.1"
fi

# Prompt completion and start VNC
echo "VNC installation completed. Start command: vchrome"
echo "You can access it via a web browser at http://$IP:$NOVNC_PORT/vnc.html or connect using a VNC client to $IP:$PORT."

# Display help information
echo "Usage:"
echo "  vchrome -i    Display VNC and Chrome version information"
echo "  vchrome -u    Upgrade VNC and Chrome"
echo "  vchrome -r    Uninstall VNC and Chrome"

# Handle command line arguments
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Usage:"
    echo "  ./install.sh [-h|--help]"
    echo "  ./install.sh [-i|--info]"
    echo "  ./install.sh [-u|--upgrade]"
    echo "  ./install.sh [-r|--remove]"
    exit 0
fi
