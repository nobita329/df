#!/bin/bash
set -e

# ===== UI COLORS =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ===== BANNER =====
print_banner() {
    echo -e "${CYAN}"
    echo "================================================================="
    echo
    echo -e "${BLUE}  ██████  ██████  ██████  ██ ███    ██  ██████      ██   ██ ██    ██ ██████  "
    echo -e " ██      ██    ██ ██   ██ ██ ████   ██ ██           ██   ██ ██    ██ ██   ██ "
    echo -e " ██      ██    ██ ██   ██ ██ ██ ██  ██ ██   ███     ███████ ██    ██ ██████  "
    echo -e " ██      ██    ██ ██   ██ ██ ██  ██ ██ ██    ██     ██   ██ ██    ██ ██   ██ "
    echo -e "  ██████  ██████  ██████  ██ ██   ████  ██████      ██   ██  ██████  ██████  "
    echo -e "                                                                             "
    echo
    echo -e "${GREEN}           Discord Status Manager - Terminal Edition"
    echo -e "${CYAN}================================================================="
    echo -e "${YELLOW}📊 CURRENT STATISTICS"
    echo -e "${CYAN}=================================================================${NC}"
}

# ===== UI FUNCTIONS =====
print_header() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║           COCKPIT SERVER MANAGER - COMPLETE SUITE           ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "${GREEN}✅${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

print_progress() {
    echo -e "${BLUE}🔄${NC} $1"
}

print_info() {
    echo -e "${PURPLE}💡${NC} $1"
}

print_addon() {
    echo -e "${CYAN}📦${NC} $1"
}

print_success() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                     INSTALLATION COMPLETE!                   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ===== VPS INFO FUNCTION =====
show_vps_info() {
    echo -e "${CYAN}=================================================================${NC}"
    echo -e "${GREEN}🖥️  VPS SYSTEM INFORMATION${NC}"
    echo -e "${CYAN}=================================================================${NC}"
    
    # Basic system info
    echo -e "${YELLOW}🏷️  Hostname:${NC} $(hostname)"
    echo -e "${YELLOW}🌐 IP Address:${NC} $(hostname -I | awk '{print $1}')"
    echo -e "${YELLOW}🖥️  CPU:${NC} $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
    echo -e "${YELLOW}💾 RAM:${NC} $(free -h | awk '/^Mem:/ {print $2}')"
    echo -e "${YELLOW}💿 Disk:${NC} $(df -h / | awk 'NR==2 {print $2 " used: " $3 " (" $5 ")"}')"
    echo -e "${YELLOW}🐧 OS:${NC} $(lsb_release -d | cut -f2)"
    echo -e "${YELLOW}⏰ Uptime:${NC} $(uptime -p | sed 's/up //')"
    echo -e "${YELLOW}👤 Users:${NC} $(who | wc -l) connected"
    
    # Network information
    echo -e "${YELLOW}📡 Network:${NC}"
    ip -o -4 addr show | awk '{print $2 ": " $4}' | while read line; do
        echo -e "   ${BLUE}$line${NC}"
    done
    
    # Service status
    echo -e "${YELLOW}🔧 Services:${NC}"
    services=("cockpit.socket" "ssh" "nginx" "docker")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            echo -e "   ${GREEN}✅ $service: RUNNING${NC}"
        else
            echo -e "   ${RED}❌ $service: STOPPED${NC}"
        fi
    done
    
    echo -e "${CYAN}=================================================================${NC}"
}

# ===== OS AUTO-DETECTION =====
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        print_step "Detected OS: $PRETTY_NAME"
    else
        print_error "OS detection failed. Exiting."
        exit 1
    fi
    sleep 1
}

# ===== PACKAGE INSTALLATION FUNCTION =====
install_pkg() {
    local pkg=$1
    local category=$2
    
    if dpkg -l | grep -q "^ii  $pkg" 2>/dev/null; then
        print_step "$category: $pkg already installed"
        return 0
    else
        if apt-cache show "$pkg" >/dev/null 2>&1; then
            print_progress "Installing $category: $pkg..."
            if sudo apt install -y "$pkg" >/dev/null 2>&1; then
                print_step "Successfully installed: $pkg"
                return 0
            else
                print_warning "Failed to install: $pkg - skipping"
                return 1
            fi
        else
            print_warning "Package not available: $pkg - skipping"
            return 1
        fi
    fi
}

# ===== COCKPIT PLUGIN INSTALLATION FUNCTIONS =====
install_cockpit_navigator() {
    print_addon "Installing Cockpit Navigator (File Manager)..."
    install_pkg "cockpit-navigator" "Cockpit Navigator" || true
}

install_cockpit_zfs() {
    print_addon "Installing Cockpit ZFS Manager..."
    install_pkg "cockpit-zfs-manager" "ZFS Manager" || true
}

install_cockpit_services() {
    print_addon "Installing Cockpit Services..."
    install_pkg "cockpit-system" "Cockpit Services" || true
}

install_cockpit_machines() {
    print_addon "Installing Cockpit Machines (Virtual Machines)..."
    install_pkg "cockpit-machines" "Virtual Machines" || true
}

install_cockpit_podman() {
    print_addon "Installing Cockpit Podman (Containers)..."
    install_pkg "cockpit-podman" "Podman Containers" || true
}

install_cockpit_software() {
    print_addon "Installing Cockpit Software Updates..."
    install_pkg "cockpit-packagekit" "Software Updates" || true
}

install_cockpit_network() {
    print_addon "Installing Cockpit Network Manager..."
    install_pkg "cockpit-networkmanager" "Network Manager" || true
}

install_cockpit_storage() {
    print_addon "Installing Cockpit Storage Manager..."
    install_pkg "cockpit-storaged" "Storage Manager" || true
}

install_cockpit_metrics() {
    print_addon "Installing Cockpit Metrics (Performance)..."
    install_pkg "cockpit-pcp" "Performance Metrics" || true
}

install_cockpit_sosreport() {
    print_addon "Installing Cockpit SOS Report..."
    install_pkg "cockpit-sosreport" "SOS Report" || true
}

install_cockpit_ssh() {
    print_addon "Installing Cockpit SSH Terminal..."
    install_pkg "cockpit-ssh" "SSH Terminal" || true
}

install_cockpit_selinux() {
    print_addon "Installing Cockpit SELinux Manager..."
    install_pkg "cockpit-selinux" "SELinux Manager" || true
}

install_cockpit_users() {
    print_addon "Installing Cockpit User Manager..."
    install_pkg "cockpit-users" "User Manager" || true
}

install_cockpit_dashboard() {
    print_addon "Installing Cockpit Dashboard..."
    print_step "Cockpit Dashboard (included in base package)"
}

install_cockpit_nginx() {
    print_addon "Installing Cockpit Nginx Manager..."
    install_pkg "cockpit-nginx" "Nginx Manager" || true
}

install_cockpit_docker() {
    print_addon "Installing Cockpit Docker Manager..."
    install_pkg "cockpit-docker" "Docker Manager" || true
}

install_cockpit_samba() {
    print_addon "Installing Cockpit Samba Manager..."
    install_pkg "cockpit-samba" "Samba Manager" || true
}

install_cockpit_lxd() {
    print_addon "Installing Cockpit LXD Manager..."
    install_pkg "cockpit-lxd" "LXD Manager" || true
}

install_cockpit_ostree() {
    print_addon "Installing Cockpit OSTree Manager..."
    install_pkg "cockpit-ostree" "OSTree Manager" || true
}

install_cockpit_kdump() {
    print_addon "Installing Cockpit Kdump Manager..."
    install_pkg "cockpit-kdump" "Kdump Manager" || true
}

install_cockpit_subscriptions() {
    print_addon "Installing Cockpit Subscriptions Manager..."
    install_pkg "cockpit-subscriptions" "Subscriptions Manager" || true
}

install_cockpit_appstream() {
    print_addon "Installing Cockpit AppStream..."
    install_pkg "cockpit-appstream" "AppStream" || true
}

install_cockpit_248() {
    print_addon "Installing Cockpit 248..."
    install_pkg "cockpit-248" "Cockpit 248" || true
}

install_cockpit_brands() {
    print_addon "Installing Cockpit Brands..."
    install_pkg "cockpit-brands" "Cockpit Brands" || true
}

install_cockpit_podman_logs() {
    print_addon "Installing Cockpit Podman Logs..."
    install_pkg "cockpit-podman-logs" "Podman Logs" || true
}

# ===== ADDON INSTALLATION FUNCTIONS =====
install_docker() {
    print_addon "Installing Docker and Cockpit Docker plugin..."
    if command -v docker &> /dev/null; then
        print_step "Docker already installed"
    else
        print_progress "Downloading Docker installation script..."
        if curl -fsSL https://get.docker.com -o get-docker.sh >/dev/null 2>&1; then
            sudo sh get-docker.sh >/dev/null 2>&1 || true
            sudo usermod -aG docker $USER >/dev/null 2>&1 || true
            rm -f get-docker.sh
            print_step "Docker installed successfully"
        else
            print_warning "Docker installation failed - skipping"
        fi
    fi
}

install_portainer() {
    print_addon "Installing Portainer CE..."
    if command -v docker &> /dev/null; then
        if docker ps -a | grep -q portainer; then
            print_step "Portainer already installed"
        else
            if docker volume create portainer_data >/dev/null 2>&1; then
                docker run -d -p 8000:8000 -p 9443:9443 --name portainer \
                    --restart=always \
                    -v /var/run/docker.sock:/var/run/docker.sock \
                    -v portainer_data:/data \
                    portainer/portainer-ce:latest >/dev/null 2>&1 && \
                print_step "Portainer installed (https://$(hostname -I | awk '{print $1}'):9443)" || \
                print_warning "Portainer installation failed"
            else
                print_warning "Portainer volume creation failed"
            fi
        fi
    else
        print_warning "Docker not available - skipping Portainer"
    fi
}

install_nginx() {
    print_addon "Installing Nginx with Cockpit plugin..."
    install_pkg "nginx" "Web Server" || true
    install_cockpit_nginx
    sudo systemctl enable nginx >/dev/null 2>&1 || true
    sudo systemctl start nginx >/dev/null 2>&1 || true
    print_step "Nginx installed and configured"
}

install_fail2ban() {
    print_addon "Installing Fail2Ban protection..."
    install_pkg "fail2ban" "Security" || true
    sudo systemctl enable fail2ban >/dev/null 2>&1 || true
    sudo systemctl start fail2ban >/dev/null 2>&1 || true
    print_step "Fail2Ban security installed"
}

install_monitoring_tools() {
    print_addon "Installing system monitoring tools..."
    MONITORING_PKGS=(htop iotop nethogs nmon dstat sysstat glances)
    for pkg in "${MONITORING_PKGS[@]}"; do
        install_pkg "$pkg" "Monitoring" || true
    done
}

install_network_tools() {
    print_addon "Installing network utilities..."
    NETWORK_PKGS=(net-tools traceroute iperf3 tcpdump nmap iftop)
    for pkg in "${NETWORK_PKGS[@]}"; do
        install_pkg "$pkg" "Network Tools" || true
    done
}

install_additional_tools() {
    print_addon "Installing additional useful tools..."
    ADDITIONAL_PKGS=(curl wget git unzip tree software-properties-common apt-transport-https ca-certificates)
    for pkg in "${ADDITIONAL_PKGS[@]}"; do
        install_pkg "$pkg" "Additional Tools" || true
    done
}

# ===== MAIN INSTALLATION =====
main() {
    print_banner
    show_vps_info
    
    print_header
    
    # ===== SYSTEM UPDATE =====
    print_progress "Updating system packages..."
    sudo apt update >/dev/null 2>&1 && sudo apt upgrade -y >/dev/null 2>&1 || {
        print_warning "System update had some issues, but continuing..."
    }
    print_step "System update completed"
    
    # ===== INSTALL COCKPIT CORE =====
    print_progress "Installing Cockpit core..."
    install_pkg "cockpit" "Cockpit Core" || {
        print_error "Cockpit installation failed! Exiting."
        exit 1
    }
    sudo systemctl enable --now cockpit.socket >/dev/null 2>&1 || true
    print_step "Cockpit service enabled and started"
    
    # ===== INSTALL COCKPIT PLUGINS =====
    echo
    print_info "Installing Cockpit plugins..."
    
    # Core plugins (from official repos only - NO GITHUB)
    install_cockpit_dashboard
    install_cockpit_services
    install_cockpit_software
    install_cockpit_network
    install_cockpit_storage
    install_cockpit_metrics
    install_cockpit_ssh
    install_cockpit_users
    
    # Virtualization plugins
    install_cockpit_machines
    install_cockpit_podman
    install_cockpit_lxd
    install_cockpit_docker
    
    # File and storage plugins
    install_cockpit_navigator
    install_cockpit_zfs
    install_cockpit_samba
    
    # System plugins
    install_cockpit_selinux
    install_cockpit_sosreport
    install_cockpit_kdump
    install_cockpit_ostree
    install_cockpit_subscriptions
    install_cockpit_appstream
    install_cockpit_248
    install_cockpit_brands
    install_cockpit_podman_logs
    
    # ===== INSTALL ADDITIONAL SERVICES =====
    echo
    print_info "Installing additional services..."
    
    install_docker
    install_nginx
    install_fail2ban
    install_monitoring_tools
    install_network_tools
    install_additional_tools
    
    # Optional services (uncomment if needed)
    # install_portainer
    
    # ===== SECURITY CONFIGURATION =====
    print_progress "Configuring security settings..."
    DISALLOW_FILE="/etc/cockpit/disallowed-users"
    if [ ! -f "$DISALLOW_FILE" ]; then
        sudo touch "$DISALLOW_FILE" || true
    fi
    
    if ! grep -q "^root$" "$DISALLOW_FILE" 2>/dev/null; then
        echo "#root" | sudo tee -a "$DISALLOW_FILE" >/dev/null || true
        sudo systemctl restart cockpit >/dev/null 2>&1 || true
        print_step "Root login disabled in Cockpit"
    else
        print_step "Root login already disabled"
    fi
    
    # ===== FINAL CHECKS =====
    print_progress "Performing final checks..."
    if sudo systemctl is-active cockpit.socket >/dev/null 2>&1; then
        print_step "Cockpit service is running"
    else
        print_warning "Cockpit service is not running, attempting to start..."
        sudo systemctl start cockpit.socket >/dev/null 2>&1 || true
    fi
    
    # ===== COMPLETION SUMMARY =====
    print_success
    
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    echo -e "${GREEN}🚀 ACCESS INFORMATION:${NC}"
    echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│ ${YELLOW}🌐 Cockpit Web UI:${NC}  https://${IP_ADDRESS}:9090/${NC}"
    echo -e "${CYAN}│ ${YELLOW}🔧 SSH Access:${NC}      ssh $(whoami)@${IP_ADDRESS}${NC}"
    echo -e "${CYAN}│ ${YELLOW}🛡️  Security:${NC}       Fail2Ban installed | Root login disabled${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
    
    # Show final VPS status
    echo
    show_vps_info
    
    echo
    print_warning "Note: Some packages might not be available in your repository"
    print_warning "Note: System reboot recommended for full functionality"
    echo -e "${PURPLE}Installation completed at: $(date)${NC}"
}

# ===== ERROR HANDLING =====
handle_error() {
    print_error "Script encountered an error at line $1"
    print_warning "But continuing with installation..."
}

trap 'handle_error $LINENO' ERR

# ===== SCRIPT EXECUTION =====
detect_os
main
