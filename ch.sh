#!/usr/bin/env bash
set -euo pipefail

DB_NAME="ctrlpanel"
DB_USER="ctrlpaneluser"
DB_PASS="ctrlpanelpass123"  # Default password

echo ""
echo ">>> CtrlPanel Installer Starting..."
echo ""

read -p "Enter your domain or IP: " DOMAIN
echo "Using: $DOMAIN"
echo ""

# ----------------------------------------------------
# CLEANUP SURY ON NOBLE
# ----------------------------------------------------
cleanup_old_sury() {
    if [ "$(lsb_release -sc)" = "noble" ]; then
        echo ">>> Noble detected — removing bad Sury repo..."
        rm -f /etc/apt/sources.list.d/php.list 2>/dev/null || true
        rm -f /usr/share/keyrings/deb.sury.org-php.gpg 2>/dev/null || true
    fi
}

# ----------------------------------------------------
# OS DETECT
# ----------------------------------------------------
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS="$ID"
        VER="$VERSION_ID"
        CODENAME=$(lsb_release -sc)
    else
        echo "ERROR: Cannot detect operating system"
        exit 1
    fi
}

check_supported() {
    case "$OS" in
        ubuntu) [[ "$VER" =~ ^(20.04|22.04|24.04)$ ]] || { echo "Unsupported Ubuntu version: $VER"; exit 1; } ;;
        debian) [[ "$VER" =~ ^(10|11|12)$ ]] || { echo "Unsupported Debian version: $VER"; exit 1; } ;;
        *) echo "Unsupported OS: $OS"; exit 1 ;;
    esac
    echo ">>> Detected: $OS $VER ($CODENAME)"
}

# ----------------------------------------------------
# BASE PACKAGES
# ----------------------------------------------------
install_base_packages() {
    echo ">>> Updating system and installing base packages..."
    apt update -y
    apt install -y software-properties-common curl apt-transport-https \
        ca-certificates gnupg lsb-release wget sudo git mariadb-server
}

# ----------------------------------------------------
# PHP AUTO-DETECT (NOBLE SAFE)
# ----------------------------------------------------
add_php_repo_auto() {
    SURY_SUPPORTED=("focal" "jammy" "bookworm" "bullseye" "buster")

    if printf "%s\n" "${SURY_SUPPORTED[@]}" | grep -q "^${CODENAME}$"; then
        echo ">>> Adding Sury PHP repo for ${CODENAME}"
        wget -qO /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
        echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ ${CODENAME} main" \
            > /etc/apt/sources.list.d/php.list
        SKIP_PHP_REPO=0
    else
        echo ">>> ${CODENAME} not supported by Sury — using system PHP."
        SKIP_PHP_REPO=1
    fi
}

# ----------------------------------------------------
# REDIS REPO
# ----------------------------------------------------
add_redis_repo() {
    echo ">>> Adding Redis repository..."
    curl -fsSL https://packages.redis.io/gpg | gpg --dearmor \
        -o /usr/share/keyrings/redis-archive-keyring.gpg

    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb ${CODENAME} main" \
        > /etc/apt/sources.list.d/redis.list
}

# ----------------------------------------------------
# PHP INSTALL AUTO-SWITCH
# ----------------------------------------------------
install_php_auto() {
    echo ">>> Installing PHP and dependencies..."
    apt update -y
    if [ "${SKIP_PHP_REPO:-1}" -eq 1 ]; then
        apt install -y php php-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip,intl} nginx redis-server
        PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
    else
        apt install -y php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip,intl,redis} nginx redis-server
        PHP_VERSION="8.3"
    fi
    echo ">>> PHP $PHP_VERSION installed"
}

enable_redis() {
    echo ">>> Enabling Redis..."
    systemctl enable --now redis-server
}

# ----------------------------------------------------
# COMPOSER
# ----------------------------------------------------
install_composer() {
    echo ">>> Installing Composer..."
    curl -sS https://getcomposer.org/installer \
        | php -- --install-dir=/usr/local/bin --filename=composer
}

# ----------------------------------------------------
# CTRLPANEL CLONE + BUILD
# ----------------------------------------------------
clone_ctrlpanel() {
    echo ">>> Cloning CtrlPanel..."
    mkdir -p /var/www/ctrlpanel
    cd /var/www/ctrlpanel
    if [ -d ".git" ]; then
        echo ">>> Existing repository found, pulling latest changes..."
        git pull origin main || true
    else
        git clone https://github.com/Ctrlpanel-gg/panel.git . || { echo "Git clone failed"; exit 1; }
    fi
}

laravel_build() {
    echo ">>> Building Laravel application..."
    cd /var/www/ctrlpanel
    COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
    php artisan storage:link
}

# ----------------------------------------------------
# SSL (Self-signed for initial setup)
# ----------------------------------------------------
setup_ssl() {
    echo ">>> Setting up temporary SSL certificates..."
    mkdir -p /etc/certs/ctrlpanel
    cd /etc/certs/ctrlpanel

    # Generate self-signed certificate for initial setup
    openssl req -new -newkey rsa:4096 -nodes -days 365 -x509 \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=${DOMAIN}" \
        -keyout privkey.pem -out fullchain.pem
    
    chmod 600 privkey.pem
}

# ----------------------------------------------------
# DATABASE
# ----------------------------------------------------
setup_mariadb() {
    echo ">>> Setting up database..."
    
    # Ensure MariaDB is running
    systemctl enable --now mariadb
    
    # Secure installation if not already done
    if ! mariadb -e "SELECT 1" >/dev/null 2>&1; then
        echo ">>> Securing MariaDB installation..."
        mysql_secure_installation <<EOF

n
y
y
y
y
EOF
    fi

    mariadb -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';" || { echo "Database user creation failed"; exit 1; }
    mariadb -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};" || { echo "Database creation failed"; exit 1; }
    mariadb -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1' WITH GRANT OPTION;" || { echo "Grant privileges failed"; exit 1; }
    mariadb -e "FLUSH PRIVILEGES;" || { echo "Flush privileges failed"; exit 1; }
    
    echo ">>> Database setup completed"
}

# ----------------------------------------------------
# NGINX CONFIG
# ----------------------------------------------------
setup_nginx() {
    echo ">>> Configuring nginx..."

    # Create nginx config
    cat > /etc/nginx/sites-available/ctrlpanel.conf <<EOF
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

    access_log /var/log/nginx/ctrlpanel.app-access.log;
    error_log  /var/log/nginx/ctrlpanel.app-error.log error;

    # Allow large upload sizes
    client_max_body_size 100m;
    client_body_timeout 120s;

    sendfile off;

    # SSL Configuration - Using self-signed for initial setup
    ssl_certificate /etc/certs/ctrlpanel/fullchain.pem;
    ssl_certificate_key /etc/certs/ctrlpanel/privkey.pem;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384";
    ssl_prefer_server_ciphers on;

    # Security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Robots-Tag none;
    add_header Content-Security-Policy "frame-ancestors 'self'";
    add_header X-Frame-Options DENY;
    add_header Referrer-Policy same-origin;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
        include /etc/nginx/fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

    # Enable site
    ln -sf /etc/nginx/sites-available/ctrlpanel.conf /etc/nginx/sites-enabled/ 2>/dev/null || true
    
    # Remove default nginx site
    rm -f /etc/nginx/sites-enabled/default
    
    echo ">>> Testing nginx configuration..."
    nginx -t || { echo "Nginx configuration test failed"; exit 1; }
    
    # Enable and restart services
    PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
    systemctl enable nginx php${PHP_VERSION}-fpm
    systemctl restart nginx php${PHP_VERSION}-fpm
    
    echo ">>> Nginx configuration completed"
}

# ----------------------------------------------------
# PERMISSIONS + CRON
# ----------------------------------------------------
setup_permissions_and_cron() {
    echo ">>> Setting up permissions and cron..."

    chown -R www-data:www-data /var/www/ctrlpanel
    chmod -R 775 /var/www/ctrlpanel/storage /var/www/ctrlpanel/bootstrap/cache

    # Install cron if not present
    if ! systemctl is-active --quiet cron; then
        apt install -y cron
    fi
    systemctl enable --now cron

    PHP_BIN=$(command -v php)

    # Add artisan scheduler to crontab
    (crontab -l 2>/dev/null | grep -v "schedule:run" ; \
        echo "* * * * * ${PHP_BIN} /var/www/ctrlpanel/artisan schedule:run --no-interaction >> /dev/null 2>&1") | crontab -
        
    echo ">>> Cron job installed for scheduler"
}

# ----------------------------------------------------
# AUTO-SETUP QUEUE SERVICE
# ----------------------------------------------------
auto_setup_queue_service() {
    echo ">>> Setting up queue worker service..."

    PHP_BIN=$(command -v php)

    cat > /etc/systemd/system/ctrlpanel.service <<EOF
[Unit]
Description=Ctrlpanel Queue Worker
After=network.target mariadb.service redis-server.service

[Service]
Type=simple
User=www-data
Group=www-data
Restart=always
RestartSec=3
StartLimitInterval=0
ExecStart=${PHP_BIN} /var/www/ctrlpanel/artisan queue:work --sleep=3 --tries=3 --max-time=3600
WorkingDirectory=/var/www/ctrlpanel
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable ctrlpanel.service
    systemctl start ctrlpanel.service
    
    # Wait a moment and check status
    sleep 2
    if systemctl is-active --quiet ctrlpanel.service; then
        echo ">>> Queue worker service is running"
    else
        echo ">>> WARNING: Queue worker service failed to start"
        systemctl status ctrlpanel.service --no-pager || true
    fi
}

# ----------------------------------------------------
# AUTO CONFIGURE ENVIRONMENT
# ----------------------------------------------------

# ----------------------------------------------------
# MAIN
# ----------------------------------------------------
main() {
    echo ">>> Starting CtrlPanel installation..."
    
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
    auto_setup_queue_service
    auto_configure_env

    echo ""
    echo "==========================================="
    echo " INSTALLATION COMPLETE "
    echo "==========================================="
    echo " URL: https://${DOMAIN}"
    echo " Database: ${DB_NAME}"
    echo " Database User: ${DB_USER}"
    echo " Database Password: ${DB_PASS}"
    echo ""
    echo " IMPORTANT:"
    echo " - Using self-signed SSL (you'll see browser warning)"
    echo " - For production, install Let's Encrypt:"
    echo "   sudo apt install certbot python3-certbot-nginx"
    echo "   sudo certbot --nginx -d ${DOMAIN}"
    echo "==========================================="
}

# Run main function
main "$@"
