#!/bin/bash

# VPS 2 ka Tailscale IP
VPS2_IP="100.122.29.128"

# Port range (change karna ho to modify)
START_PORT=19201
END_PORT=19250

# Install socat agar nahi hai
if ! command -v socat &> /dev/null; then
    echo "Installing socat..."
    sudo apt update && sudo apt install -y socat
fi

# Create systemd service
SERVICE_FILE="/etc/systemd/system/port-forward.service"

sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=TCP+UDP Port Forward $START_PORT-$END_PORT to VPS2 via Tailscale
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c "for port in \$(seq $START_PORT $END_PORT); do \
  socat TCP-LISTEN:\$port,fork TCP:$VPS2_IP:\$port & \
  socat UDP-LISTEN:\$port,fork UDP:$VPS2_IP:\$port & \
done; wait"
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd, enable & start service
sudo systemctl daemon-reload
sudo systemctl enable port-forward
sudo systemctl restart port-forward

echo "✅ TCP + UDP ports $START_PORT-$END_PORT VPS2 ($VPS2_IP) pe forward ho gaye aur service auto start setup ho gaya!"
sudo systemctl status port-forward --no-pager
