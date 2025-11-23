#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to get domain input with simple UI
get_domain() {
    echo -e "\n${GREEN}┌─────────────────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}│              CTRLPANEL INSTALLATION SCRIPT             │${NC}"
    echo -e "${GREEN}└─────────────────────────────────────────────────────────┘${NC}"
    echo -e ""
    echo -e "${YELLOW}Please enter your domain name for CtrlPanel${NC}"
    echo -e "${BLUE}Example: panel.yourdomain.com${NC}"
    echo -e ""
    
    while true; do
        read -p "➤ Enter your domain: " DOMAIN_NAME
        
        if [ -z "$DOMAIN_NAME" ]; then
            print_error "Domain name cannot be empty. Please try again."
        elif ! echo "$DOMAIN_NAME" | grep -qE '^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'; then
            print_error "Invalid domain format. Please enter a valid domain."
        else
            break
        fi
    done
    
    echo -e ""
    echo -e "${GREEN}✓ Domain set to: $DOMAIN_NAME${NC}"
    echo -e "${YELLOW}Starting installation...${NC}"
    echo -e ""
}

# Function to detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS="rhel"
        OS_VERSION=$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release)
    else
        print_error "Unsupported operating system"
        exit 1
    fi
}

# Function to get web user and group
get_web_user() {
    if [ "$OS" = "debian" ] || [ "$OS" = "ubuntu" ]; then
        echo "www-data"
    elif [ "$OS" = "rhel" ] || [ "$OS" = "centos" ] || [ "$OS" = "fedora" ] || [ "$OS" = "rocky" ] || [ "$OS" = "almalinux" ]; then
        echo "nginx"
    elif [ "$OS" = "alpine" ]; then
        echo "nginx"
    else
        echo "www-data"
    fi
}

# Function to install dependencies for Debian/Ubuntu
install_debian() {
    echo -e "${YELLOW}📦 Detected Debian-based system ($OS $OS_VERSION)${NC}"
    
    # Install basic dependencies
    apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg lsb-release

    # Add additional repositories for PHP
    wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list

    # Add Redis official APT repository
    curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/redis.list

    # Update repositories list
    apt update -y

    # Install Dependencies
    apt install -y php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip,intl,redis} mariadb-server nginx git redis-server
}

# Function to install dependencies for RHEL/CentOS
install_rhel() {
    echo -e "${YELLOW}📦 Detected RHEL-based system ($OS $OS_VERSION)${NC}"
    
    # Install EPEL repository
    dnf install -y epel-release
    
    # Install Remi repository for PHP
    dnf install -y https://rpms.remirepo.net/enterprise/remi-release-${OS_VERSION}.rpm
    
    # Enable PHP 8.3 stream
    dnf module enable -y php:remi-8.3
    
    # Install basic dependencies
    dnf install -y curl wget gnupg2
    
    # Add Redis repository
    if [ ${OS_VERSION%%.*} -eq 8 ] || [ ${OS_VERSION%%.*} -eq 9 ]; then
        dnf install -y https://rpms.remirepo.net/enterprise/remi-release-${OS_VERSION}.rpm
        dnf module enable -y redis:remi-7.2
    fi
    
    # Install packages
    dnf install -y php php-{common,cli,gd,mysqlnd,mbstring,bcmath,xml,fpm,curl,zip,intl,redis} mariadb-server nginx git redis
}

# Function to setup services
setup_services() {
    print_status "🔧 Setting up and enabling services..."
    
    # Enable and start Redis
    if systemctl enable --now redis-server 2>/dev/null; then
        print_success "Redis server enabled and started"
    elif systemctl enable --now redis 2>/dev/null; then
        print_success "Redis service enabled and started"
    else
        print_warning "Could not enable Redis service"
    fi
    
    # Enable and start MariaDB/MySQL
    if systemctl enable --now mariadb 2>/dev/null; then
        print_success "MariaDB enabled and started"
    elif systemctl enable --now mysql 2>/dev/null; then
        print_success "MySQL enabled and started"
    else
        print_warning "Could not enable database service"
    fi
    
    # Enable and start Nginx
    if systemctl enable --now nginx 2>/dev/null; then
        print_success "Nginx enabled and started"
    else
        print_warning "Could not enable Nginx service"
    fi
    
    # Enable and start PHP-FPM
    if systemctl enable --now php8.3-fpm 2>/dev/null; then
        print_success "PHP 8.3 FPM enabled and started"
    elif systemctl enable --now php-fpm 2>/dev/null; then
        print_success "PHP FPM enabled and started"
    else
        print_warning "Could not enable PHP-FPM service"
    fi
}

# Function to install Composer
install_composer() {
    print_status "📦 Installing Composer..."
    
    if curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer; then
        print_success "Composer installed successfully"
    else
        print_error "Failed to install Composer"
        return 1
    fi
}

# Function to setup application
setup_application() {
    print_status "🚀 Setting up CtrlPanel application..."
    
    # Create directory and clone repository
    mkdir -p /var/www/ctrlpanel
    cd /var/www/ctrlpanel
    
    if [ -d ".git" ]; then
        print_warning "CtrlPanel already exists, pulling latest changes..."
        git pull origin main
    else
        print_status "Cloning CtrlPanel repository..."
        git clone https://github.com/Ctrlpanel-gg/panel.git ./
    fi
    
    if [ $? -eq 0 ]; then
        print_success "CtrlPanel application setup completed"
    else
        print_error "Failed to setup CtrlPanel application"
        return 1
    fi
}

# Function to setup MariaDB database
setup_database() {
    print_status "🗄️ Setting up MariaDB database..."
    
    # Database configuration
    DB_NAME=ctrlpanel
    DB_USER=ctrlpaneluser
    DB_PASS=ctrlpanel
    
    # Start MariaDB if not running
    if ! systemctl is-active --quiet mariadb && ! systemctl is-active --quiet mysql; then
        print_status "Starting database service..."
        systemctl start mariadb 2>/dev/null || systemctl start mysql 2>/dev/null
    fi
    
    # Create database and user
    mariadb -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';" 2>/dev/null
    mariadb -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};" 2>/dev/null
    mariadb -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1' WITH GRANT OPTION;" 2>/dev/null
    mariadb -e "FLUSH PRIVILEGES;" 2>/dev/null
    
    print_success "Database '${DB_NAME}' created with user '${DB_USER}'"
}

# Function to setup application dependencies and permissions
setup_app_dependencies() {
    print_status "📦 Installing PHP dependencies..."
    
    cd /var/www/ctrlpanel
    
    # Install Composer dependencies
    if COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader; then
        print_success "Composer dependencies installed"
    else
        print_error "Failed to install Composer dependencies"
        return 1
    fi
    
    # Create storage link
    print_status "Creating storage link..."
    if php artisan storage:link; then
        print_success "Storage link created"
    else
        print_warning "Could not create storage link"
    fi
    
    # Setup permissions
    print_status "Setting up permissions..."
    WEB_USER=$(get_web_user)
    
    chown -R $WEB_USER:$WEB_USER /var/www/ctrlpanel/
    chmod -R 755 storage/ bootstrap/cache/
    chmod -R 775 storage/ bootstrap/cache/
    
    print_success "Permissions configured for user: $WEB_USER"
}

# Function to setup SSL certificates
setup_ssl() {
    print_status "🔒 Setting up SSL certificates..."
    
    # Create directory for certificates
    mkdir -p /etc/certs/ctrlpanel
    cd /etc/certs/ctrlpanel
    
    # Generate self-signed certificate
    print_status "Generating self-signed SSL certificate..."
    openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
        -subj "/C=NA/ST=NA/L=NA/O=NA/CN=$DOMAIN_NAME" \
        -keyout privkey.pem -out fullchain.pem
        
    if [ $? -eq 0 ]; then
        print_success "Self-signed SSL certificate generated"
    else
        print_error "Failed to generate SSL certificate"
        return 1
    fi
}

# Function to create nginx configuration
create_nginx_config() {
    NGINX_CONF="/etc/nginx/sites-available/ctrlpanel.conf"
    
    print_status "🌐 Creating Nginx configuration..."
    
    # Create nginx configuration
    cat > $NGINX_CONF << EOF
# CtrlPanel Nginx Configuration
# Auto-generated by installation script

server {
    # Redirect HTTP to HTTPS
    listen 80;
    server_name $DOMAIN_NAME;
    return 301 https://\$server_name\$request_uri;
}

server {
    # Main HTTPS server
    listen 443 ssl http2;
    server_name $DOMAIN_NAME;

    root /var/www/ctrlpanel/public;
    index index.php;

    access_log /var/log/nginx/ctrlpanel.app-access.log;
    error_log  /var/log/nginx/ctrlpanel.app-error.log error;

    # Allow large upload sizes
    client_max_body_size 100m;
    client_body_timeout 120s;

    sendfile off;

    # SSL Configuration
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

    # Enable the site
    if [ -d "/etc/nginx/sites-enabled" ]; then
        ln -sf $NGINX_CONF /etc/nginx/sites-enabled/ctrlpanel.conf
    fi
    
    # For RHEL-based systems
    if [ "$OS" = "rhel" ] || [ "$OS" = "centos" ] || [ "$OS" = "fedora" ] || [ "$OS" = "rocky" ] || [ "$OS" = "almalinux" ]; then
        if ! grep -q "sites-enabled" /etc/nginx/nginx.conf; then
            sed -i '/http {/a\    include /etc/nginx/sites-enabled/*.conf;' /etc/nginx/nginx.conf
        fi
    fi
}

# Function to setup cron jobs
setup_cron() {
    print_status "⏰ Setting up cron jobs..."
    
    # Install cron if not installed
    if [ "$OS" = "debian" ] || [ "$OS" = "ubuntu" ]; then
        apt install -y cron
    elif [ "$OS" = "rhel" ] || [ "$OS" = "centos" ] || [ "$OS" = "fedora" ] || [ "$OS" = "rocky" ] || [ "$OS" = "almalinux" ]; then
        dnf install -y cronie
    fi
    
    # Enable and start cron service
    if systemctl enable --now cron 2>/dev/null || systemctl enable --now crond 2>/dev/null; then
        print_success "Cron service enabled and started"
    else
        print_warning "Could not enable cron service"
    fi
    
    # Add Laravel scheduler cron job
    CRON_JOB="* * * * * php /var/www/ctrlpanel/artisan schedule:run >> /dev/null 2>&1"
    
    if ! crontab -l 2>/dev/null | grep -q "artisan schedule:run"; then
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        print_success "Cron job added for Laravel scheduler"
    else
        print_warning "Cron job already exists"
    fi
}

# Function to setup systemd service for queue worker
setup_queue_worker() {
    print_status "⚙️ Setting up CtrlPanel queue worker service..."
    
    WEB_USER=$(get_web_user)
    SERVICE_FILE="/etc/systemd/system/ctrlpanel.service"
    
    # Create systemd service file
    cat > $SERVICE_FILE << EOF
# Ctrlpanel Queue Worker
[Unit]
Description=Ctrlpanel Queue Worker

[Service]
User=$WEB_USER
Group=$WEB_USER
Restart=always
ExecStart=/usr/bin/php /var/www/ctrlpanel/artisan queue:work --sleep=3 --tries=3
StartLimitBurst=0

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable service
    systemctl daemon-reload
    
    if systemctl enable --now ctrlpanel.service; then
        print_success "CtrlPanel queue worker service enabled and started"
    else
        print_error "Failed to enable CtrlPanel queue worker service"
        return 1
    fi
}

# Function to finalize nginx setup
finalize_nginx() {
    print_status "🔧 Finalizing Nginx configuration..."
    
    # Test nginx configuration
    if nginx -t; then
        print_success "Nginx configuration test passed"
        systemctl reload nginx
        print_success "Nginx reloaded successfully"
    else
        print_error "Nginx configuration test failed"
        return 1
    fi
}

# Function to display final information
display_info() {
    echo -e "\n${GREEN}┌─────────────────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}│                 INSTALLATION COMPLETE                   │${NC}"
    echo -e "${GREEN}└─────────────────────────────────────────────────────────┘${NC}"
    echo -e ""
    echo -e "${YELLOW}📋 Summary:${NC}"
    echo -e "  • Domain: ${GREEN}$DOMAIN_NAME${NC}"
    echo -e "  • OS: $OS $OS_VERSION"
    echo -e "  • Application: ${GREEN}/var/www/ctrlpanel${NC}"
    echo -e "  • Database: ${GREEN}ctrlpanel${NC}"
    echo -e "  • SSL: ${YELLOW}Self-signed certificate${NC}"
    echo -e ""
    echo -e "${YELLOW}🚀 Next Steps:${NC}"
    echo -e "  1. Update DNS to point ${GREEN}$DOMAIN_NAME${NC} to your server IP"
    echo -e "  2. Configure your .env file in /var/www/ctrlpanel"
    echo -e "  3. Run: ${BLUE}php artisan migrate${NC}"
    echo -e "  4. Access your panel at: ${GREEN}https://$DOMAIN_NAME${NC}"
    echo -e ""
    echo -e "${YELLOW}⚠️ Note:${NC}"
    echo -e "  Browser will show SSL warning (self-signed certificate)"
    echo -e "  For production, replace with valid SSL certificate"
    echo -e ""
    echo -e "${GREEN}✅ All services are running!${NC}"
    echo -e ""
}

# Main script
main() {
    # Get domain information first
    get_domain
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run as root"
        exit 1
    fi
    
    # Detect OS
    detect_os
    
    # Install dependencies based on OS
    case $OS in
        debian|ubuntu)
            install_debian
            ;;
        rhel|centos|fedora|rocky|almalinux)
            install_rhel
            ;;
        *)
            print_error "Unsupported OS: $OS"
            exit 1
            ;;
    esac
    
    # Setup services
    setup_services
    
    # Install Composer
    install_composer
    
    # Setup application
    setup_application
    
    # Setup database
    setup_database
    
    # Setup application dependencies and permissions
    setup_app_dependencies
    
    # Setup SSL certificates
    setup_ssl
    
    # Create nginx configuration
    create_nginx_config
    
    # Setup cron jobs
    setup_cron
    
    # Setup queue worker
    setup_queue_worker
    
    # Finalize nginx
    finalize_nginx
    
    # Display final information
    display_info
}

# Run main function
main
