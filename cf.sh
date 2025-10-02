#!/bin/bash

# VPS 2 ka Tailscale IP
VPS2_IP="100.122.29.128"

# Install socat agar nahi hai
if ! command -v socat &> /dev/null; then
    echo "Installing socat..."
    sudo apt update && sudo apt install -y socat
fi

# Create systemd service
SERVICE_FILE="/etc/systemd/system/port-forward.service"

sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=TCP Port Forward 19201-19202 to VPS2 via Tailscale
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'for port in \$(seq 19201 19202); do socat TCP-LISTEN:\$port,fork TCP:$VPS2_IP:\$port & done; wait'
Restart=always

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd, enable & start service
sudo systemctl daemon-reload
sudo systemctl enable port-forward
sudo systemctl start port-forward

echo "✅ TCP ports 19201-19202 VPS2 ($VPS2_IP) pe forward ho gaye aur service auto start setup ho gaya!"
sudo systemctl status port-forward --no-pager
