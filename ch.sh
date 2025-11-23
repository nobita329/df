#!/usr/bin/env bash
set -euo pipefail

DB_NAME="ctrlpanel"
DB_USER="ctrlpaneluser"

echo ""
echo ">>> CtrlPanel Installer Starting..."
echo ""

# Get domain/IP
read -p "Enter your domain or IP: " DOMAIN
echo "Using: $DOMAIN"
echo ""

# Get secure DB password
read -s -p "Enter database password: " DB_PASS
echo ""
read -s -p "Confirm database password: " DB_PASS_CONFIRM
echo ""

if [ "$DB_PASS" != "$DB_PASS_CONFIRM" ]; then
    echo "ERROR: Passwords do not match!"
    exit 1
fi

if [ -z "$DB_PASS" ]; then
    echo "ERROR: Database password cannot be empty!"
    exit 1
fi

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
# SSL
# ----------------------------------------------------
setup_ssl() {
    echo ">>> Setting up SSL certificates..."
    mkdir -p /etc/certs/ctrlpanel
    cd /etc/certs/ctrlpanel

    # Generate better certificate info
    openssl req -new -newkey rsa:4096 -nodes -days 3650 -x509 \
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

    # Get PHP version for socket
    PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
    
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

    ssl_certificate /etc/certs/ctrlpanel/fullchain.pem;
    ssl_certificate_key /etc/certs/ctrlpanel/privkey.pem;

    client_max_body_size 100m;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
    }

    location ~ /\.ht {
        deny all;
    }
    
    location ~ /\.env {
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
    
    systemctl enable nginx php${PHP_VERSION}-fpm
    systemctl restart nginx php${PHP_VERSION}-fpm
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

sudo tee /etc/systemd/system/ctrlpanel.service > /dev/null << EOF
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
# FINAL SETUP STEPS
# ----------------------------------------------------
final_setup() {
    echo ">>> Running final setup steps..."
    cd /var/www/ctrlpanel
    
    # Copy environment file
    if [ -f .env.example ] && [ ! -f .env ]; then
        cp .env.example .env
        php artisan key:generate
    fi
    
    # Update .env with database credentials
    if [ -f .env ]; then
        sed -i "s/DB_DATABASE=.*/DB_DATABASE=${DB_NAME}/" .env
        sed -i "s/DB_USERNAME=.*/DB_USERNAME=${DB_USER}/" .env
        sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${DB_PASS}/" .env
        sed -i "s/APP_URL=.*/APP_URL=https:\/\/${DOMAIN}/" .env
    fi
    
    # Run migrations if env file exists
    if [ -f .env ]; then
        php artisan migrate --force || echo "NOTE: Migrations may need to be run manually after additional configuration"
    fi
}

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
    final_setup

    echo ""
    echo "==========================================="
    echo " INSTALLATION COMPLETE "
    echo "==========================================="
    echo " URL: https://${DOMAIN}"
    echo " Database: ${DB_NAME}"
    echo " Database User: ${DB_USER}"
    echo ""
    echo " Next steps:"
    echo " 1. Configure your .env file in /var/www/ctrlpanel"
    echo " 2. Run: php artisan migrate --force"
    echo " 3. Set up a real SSL certificate (Let's Encrypt)"
    echo " 4. Configure your application settings"
    echo "==========================================="
}

# Run main function
main "$@"
