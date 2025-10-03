#!/bin/bash

# Dusre VPS ke IPs
VPS3_IP="100.117.193.1"
VPS4_IP="100.97.202.93"
VPS5_IP="100.122.29.128"

# Install socat agar nahi hai
if ! command -v socat &> /dev/null; then
    echo "Installing socat..."
    sudo apt update && sudo apt install -y socat
fi

# Create systemd service
SERVICE_FILE="/etc/systemd/system/port-forward.service"

sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=TCP+UDP Port Forward to multiple VPS via Tailscale
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c '
# Pehle se wala range (TCP only, VPS2 fix IP hardcode kar diya)
for port in \$(seq 25601 25700); do
    socat TCP-LISTEN:\$port,fork TCP:100.71.233.115:\$port &
done

# New ranges TCP+UDP
# VPS3
for port in \$(seq 19100 19150); do
    socat TCP-LISTEN:\$port,fork TCP:$VPS3_IP:\$port &
    socat UDP-LISTEN:\$port,fork UDP:$VPS3_IP:\$port &
done

# VPS4
for port in \$(seq 19151 19200); do
    socat TCP-LISTEN:\$port,fork TCP:$VPS4_IP:\$port &
    socat UDP-LISTEN:\$port,fork UDP:$VPS4_IP:\$port &
done

# VPS5
for port in \$(seq 19201 19250); do
    socat TCP-LISTEN:\$port,fork TCP:$VPS5_IP:\$port &
    socat UDP-LISTEN:\$port,fork UDP:$VPS5_IP:\$port &
done

wait
'
Restart=always

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd, enable & start service
sudo systemctl daemon-reload
sudo systemctl enable port-forward
sudo systemctl restart port-forward

echo "✅ Port forwarding setup complete!"
sudo systemctl status port-forward --no-pager
