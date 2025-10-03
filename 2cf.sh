#!/bin/bash

# VPS IPs
VPS3_IP="100.117.193.1"
VPS4_IP="100.97.202.93"
VPS5_IP="100.122.29.128"

# Purana service delete karo
sudo systemctl stop port-forward 2>/dev/null
sudo systemctl disable port-forward 2>/dev/null
sudo rm -f /etc/systemd/system/port-forward.service
sudo rm -f /usr/local/bin/port-forward.sh

# Install socat agar missing ho
if ! command -v socat &> /dev/null; then
    echo "Installing socat..."
    sudo apt update && sudo apt install -y socat
fi

# Forward script create
FORWARD_SCRIPT="/usr/local/bin/port-forward.sh"
sudo bash -c "cat > $FORWARD_SCRIPT" <<'EOS'
#!/bin/bash

# VPS3 TCP only
for port in $(seq 19100 19150); do
    socat TCP-LISTEN:$port,fork,reuseaddr TCP:100.117.193.1:$port &
done

# VPS4 TCP only
for port in $(seq 19151 19200); do
    socat TCP-LISTEN:$port,fork,reuseaddr TCP:100.97.202.93:$port &
done

# VPS5 TCP only
for port in $(seq 19201 19250); do
    socat TCP-LISTEN:$port,fork,reuseaddr TCP:100.122.29.128:$port &
done

wait
EOS

sudo chmod +x $FORWARD_SCRIPT

# Systemd service create
SERVICE_FILE="/etc/systemd/system/port-forward.service"
sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=TCP Port Forward to VPS3,VPS4,VPS5 via Tailscale
After=network.target

[Service]
ExecStart=$FORWARD_SCRIPT
Restart=always

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd
sudo systemctl daemon-reload
sudo systemctl enable port-forward
sudo systemctl restart port-forward

echo "✅ Old forwards removed. Only TCP 19100–19250 active now."
sudo systemctl status port-forward --no-pager
