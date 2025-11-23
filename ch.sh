#!/usr/bin/env bash
set -euo pipefail

DB_NAME="ctrlpanel"
DB_USER="ctrlpaneluser"
DB_PASS="USE_YOUR_OWN_PASSWORD"

echo ""
echo ">>> CtrlPanel Installer Rolling..."
echo ""

read -p "Enter your domain or IP: " DOMAIN
echo "Using: $DOMAIN"
echo ""

# ----------------------------------------------------
# Remove bad Sury repo on noble
# ----------------------------------------------------
cleanup_old_sury() {
    if [ "$(lsb_release -sc)" = "noble" ]; then
        echo ">>> Purging old Sury repo (noble fix)"
        rm -f /etc/apt/sources.list.d/php.list
        rm -f /usr/share/keyrings/deb.sury.org-php.gpg
    fi
}

# ----------------------------------------------------
# Detect OS
# ----------------------------------------------------
detect_os() {
    . /etc/os-release
    OS="$ID"
    VER="$VERSION_ID"
    CODENAME=$(lsb_release -sc)
}

check_supported() {
    case "$OS" in
        ubuntu) [[ "$VER" =~ ^(20.04|22.04|24.04)$ ]] || exit 1;;
        debian) [[ "$VER" =~ ^(10|11|12)$ ]] || exit 1;;
        *) exit 1;;
    esac
}

# ----------------------------------------------------
# Base packages
# ----------------------------------------------------
install_base_packages() {
    apt update -y
    apt install -y software-properties-common curl apt-transport-https \
        ca-certificates gnupg lsb-release wget sudo git mariadb-server
}

# ----------------------------------------------------
# PHP repo auto-detect
# ----------------------------------------------------
add_php_repo_auto() {
    SURY_SUPPORTED=("focal" "jammy" "bookworm" "bullseye" "buster")

    if printf "%s\n" "${SURY_SUPPORTED[@]}" | grep -q "^${CODENAME}$"; then
        echo ">>> Enabling Sury for ${CODENAME}"
        wget -qO /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
        echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ ${CODENAME} main" \
            > /etc/apt/sources.list.d/php.list
        SKIP_PHP_REPO=0
    else
        echo ">>> ${CODENAME}: Sury not supported → Using system PHP"
        SKIP_PHP_REPO=1
    fi
}

# ----------------------------------------------------
# Redis Repo
# ----------------------------------------------------
add_redis_repo() {
    curl -fsSL https://packages.redis.io/gpg | gpg --dearmor \
        -o /usr/share/keyrings/redis-archive-keyring.gpg

    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb ${CODENAME} main" \
        > /etc/apt/sources.list.d/redis.list
}

# ----------------------------------------------------
# PHP Auto Install
# ----------------------------------------------------
install_php_auto() {
    apt update -y
    if [ "${SKIP_PHP_REPO:-1}" -eq 1 ]; then
        apt install -y php php-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip,intl} nginx redis-server
    else
        apt install -y php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip,intl,redis} nginx redis-server
    fi
}

enable_redis() {
    systemctl enable --now redis-server
}

# ----------------------------------------------------
# Composer
# ----------------------------------------------------
install_composer() {
    curl -sS https://getcomposer.org/installer \
        | php -- --install-dir=/usr/local/bin --filename=composer
}

# ----------------------------------------------------
# CtrlPanel Clone
# ----------------------------------------------------
clone_ctrlpanel() {
    mkdir -p /var/www/ctrlpanel
    cd /var/www/ctrlpanel
    git clone https://github.com/Ctrlpanel-gg/panel.git ./ || true
}

laravel_build() {
    cd /var/www/ctrlpanel
    COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
    php artisan storage:link
}

# ----------------------------------------------------
# SSL
# ----------------------------------------------------
setup_ssl() {
    mkdir -p /etc/certs/ctrlpanel
    cd /etc/certs/ctrlpanel

    openssl req -new -newkey rsa:4096 -nodes -days 3650 -x509 \
        -subj "/C=NA/ST=NA/L=NA/O=NA/CN=${DOMAIN}" \
        -keyout privkey.pem -out fullchain.pem
}

# ----------------------------------------------------
# MariaDB
# ----------------------------------------------------
setup_mariadb() {
    mariadb -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';"
    mariadb -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"
    mariadb -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1' WITH GRANT OPTION;"
    mariadb -e "FLUSH PRIVILEGES;"
}

# ----------------------------------------------------
# Nginx Setup
# ----------------------------------------------------
setup_nginx() {
cat >/etc/nginx/sites-available/ctrlpanel.conf <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    root /var/www/ctrlpanel/public;
    index index.php;

    ssl_certificate /etc/certs/ctrlpanel/fullchain.pem;
    ssl_certificate_key /etc/certs/ctrlpanel/privkey.pem;

    client_max_body_size 100m;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php*.fpm.sock;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/ctrlpanel.conf /etc/nginx/sites-enabled/
    nginx -t
    systemctl restart nginx
}

# ----------------------------------------------------
# Permissions + Cron
# ----------------------------------------------------
setup_permissions_and_cron() {
    chown -R www-data:www-data /var/www/ctrlpanel
    chmod -R 775 /var/www/ctrlpanel/storage /var/www/ctrlpanel/bootstrap/cache

    apt install -y cron
    systemctl enable --now cron

    PHP_BIN=$(command -v php)

    (crontab -l 2>/dev/null | grep -v "schedule:run" ; \
        echo "* * * * * ${PHP_BIN} /var/www/ctrlpanel/artisan schedule:run >> /dev/null 2>&1") | crontab -
}

# ----------------------------------------------------
# EXACT QUEUE SERVICE (AS YOU REQUESTED)
# ----------------------------------------------------
create_queue_service() {
echo ">>> Creating exact ctrlpanel.service file..."

cat >/etc/systemd/system/ctrlpanel.service <<'EOF'
# Ctrlpanel Queue Worker File
# ----------------------------------

[Unit]
Description=Ctrlpanel Queue Worker

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/ctrlpanel/artisan queue:work --sleep=3 --tries=3
StartLimitBurst=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now ctrlpanel.service
}

# ----------------------------------------------------
# Main
# ----------------------------------------------------
main() {
    cleanup_old_sury
    detect_os
    check_supported

    install_base_packages
    add_php_repo_auto
    add_redis_repo
    install_php_auto
    enable_redis
    install_composer
    clone_ctrlpanel
    laravel_build
    setup_ssl
    setup_mariadb
    setup_nginx
    setup_permissions_and_cron
    create_queue_service

    echo ""
    echo "==========================================="
    echo " INSTALLATION COMPLETE "
    echo " URL: https://${DOMAIN}"
    echo " DB User: ${DB_USER}"
    echo " DB Pass: ${DB_PASS}"
    echo "==========================================="
}

main "$@"
