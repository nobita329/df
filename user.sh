cat >/tmp/full_nobita_setup.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

USERNAME="nobita"
PASSWORD="nobitayt"
HOME_DIR="/home/${USERNAME}"
SUDOERS_FILE="/etc/sudoers.d/${USERNAME}"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root." >&2
  exit 1
fi

# ========================
# 1) Remove home folder if exists
# ========================
if [ -d "${HOME_DIR}" ]; then
  rm -rf -- "${HOME_DIR}"
  echo "[*] Removed home folder: ${HOME_DIR}"
else
  echo "[*] Home folder not present: ${HOME_DIR}"
fi

# ========================
# 2) Create or update user
# ========================
if id "${USERNAME}" >/dev/null 2>&1; then
  echo "[*] User ${USERNAME} exists. Updating password & groups..."
else
  useradd -m -s /bin/bash "${USERNAME}" && echo "[*] Created user ${USERNAME}"
fi

# Set password
echo "${USERNAME}:${PASSWORD}" | chpasswd
echo "[*] Password set: ${PASSWORD}"

# Detect admin group (Debian/Ubuntu: sudo, RHEL/CentOS: wheel)
ADMIN_GROUP="sudo"
if grep -qiE "debian|ubuntu|mint" /etc/os-release 2>/dev/null || grep -qi "ID_LIKE=debian" /etc/os-release 2>/dev/null; then
  ADMIN_GROUP="sudo"
else
  ADMIN_GROUP="wheel"
fi

# Ensure group exists & add user
getent group "${ADMIN_GROUP}" >/dev/null 2>&1 || groupadd -r "${ADMIN_GROUP}" || true
usermod -aG "${ADMIN_GROUP}" "${USERNAME}" || true

# Ensure sudo installed
if ! command -v sudo >/dev/null 2>&1; then
  echo "[*] Installing sudo..."
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y && apt-get install -y sudo || true
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y sudo || true
  elif command -v yum >/dev/null 2>&1; then
    yum install -y sudo || true
  fi
fi

# Grant NOPASSWD sudo
printf "%s ALL=(ALL) NOPASSWD:ALL\n" "${USERNAME}" > "${SUDOERS_FILE}"
chmod 440 "${SUDOERS_FILE}"
echo "[*] NOPASSWD sudo configured for ${USERNAME}"

# ========================
# 3) Clear logs and temporary files (best-effort)
# ========================
echo "[*] Clearing logs and temp files..."
rm -rf /var/log/* /tmp/* /var/tmp/* /var/cache/* 2>/dev/null || true
if command -v journalctl >/dev/null 2>&1; then
  journalctl --rotate 2>/dev/null || true
  journalctl --vacuum-time=1s 2>/dev/null || true
fi
find / -type f -name "*.log" -delete 2>/dev/null || true
echo "[*] Logs and temp cleared."

# ========================
# 4) Final output
# ========================
echo
echo "=== SETUP COMPLETE ==="
echo "Username: ${USERNAME}"
echo "Password: ${PASSWORD}"
echo "Sudo: NOPASSWD configured"
echo "Home present:"; [ -d "${HOME_DIR}" ] && echo "yes (${HOME_DIR})" || echo "no"
echo "Logs cleared (best-effort)"
echo "====================="
EOF

chmod +x /tmp/full_nobita_setup.sh
echo "Script written to /tmp/full_nobita_setup.sh. Run with:"
echo "  sudo /tmp/full_nobita_setup.sh"
