#!/bin/bash

# Dusre VPS ke IPs
VPS2_IP="100.71.233.115"
VPS3_IP="100.117.193.1"
VPS4_IP="100.97.202.93"
VPS5_IP="100.122.29.128"

# Install socat agar nahi hai
if ! command -v socat &> /dev/null; then
    echo "Installing socat..."
    sudo apt update && sudo apt install -y socat
fi

# Forward script banate hain
FORWARD_SCRIPT="/usr/local/bin/port-forward.sh"
sudo bash -c "cat > $FORWARD_SCRIPT" <<'EOS'
#!/bin/bash
# VPS2 TCP only
for port in $(seq 25601 25700); do
    socat TCP-LISTEN:$port,fork,reuseaddr TCP:100.71.233.115:$port &
done

# VPS3 TCP+UDP
for port in $(seq 19100 19150); do
    socat TCP-LISTEN:$port,fork,reuseaddr TCP:100.117.193.1:$port &
    socat UDP-LISTEN:$port,fork,reuseaddr UDP:100.117.193.1:$port &
done

# VPS4 TCP+UDP
for port in $(seq 19151 19200); do
    socat TCP-LISTEN:$port,fork,reuseaddr TCP:100.97.202.93:$port &
    socat UDP-LISTEN:$port,fork,reuseaddr UDP:100.97.202.93:$port &
done

# VPS5 TCP+UDP
for port in $(seq 19201 19250); do
    socat TCP-LISTEN:$port,fork,reuseaddr TCP:100.122.29.128:$port &
    socat UDP-LISTEN:$port,fork,reuseaddr UDP:100.122.29.128:$port &
done

wait
EOS

sudo chmod +x $FORWARD_SCRIPT

# Systemd service
SERVICE_FILE="/etc/systemd/system/port-forward.service"
sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=TCP+UDP Port Forward to multiple VPS via Tailscale
After=network.target

[Service]
ExecStart=$FORWARD_SCRIPT
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
