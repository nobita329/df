#!/bin/bash

# ==============================================
# LXC Container Management Menu
# Author: Your Name
# Version: 2.0
# ==============================================

# Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration
CONFIG_DIR="$HOME/.lxc_manager"
CONFIG_FILE="$CONFIG_DIR/config.conf"
LOG_FILE="$CONFIG_DIR/lxc_manager.log"
BACKUP_DIR="$CONFIG_DIR/backups"

# Default Settings
DEFAULT_STORAGE="default"
DEFAULT_NETWORK="lxdbr0"
AUTO_BACKUP=true
NOTIFY=true

# OS Templates
declare -A OS_TEMPLATES=(
    [1]="ubuntu:20.04"
    [2]="ubuntu:22.04"
    [3]="ubuntu:24.04"
    [4]="debian:10"
    [5]="debian:11"
    [6]="debian:12"
    [7]="centos:7"
    [8]="centos:8"
    [9]="almalinux:9"
    [10]="rockylinux:9"
    [11]="alpine:edge"
    [12]="archlinux"
    [13]="opensuse/tumbleweed"
    [14]="fedora:40"
)

declare -A OS_NAMES=(
    [1]="Ubuntu 20.04 LTS"
    [2]="Ubuntu 22.04 LTS"
    [3]="Ubuntu 24.04 LTS"
    [4]="Debian 10 Buster"
    [5]="Debian 11 Bullseye"
    [6]="Debian 12 Bookworm"
    [7]="CentOS 7"
    [8]="CentOS 8"
    [9]="AlmaLinux 9"
    [10]="Rocky Linux 9"
    [11]="Alpine Linux Edge"
    [12]="Arch Linux"
    [13]="openSUSE Tumbleweed"
    [14]="Fedora 40"
)

# Initialize
init_system() {
    mkdir -p "$CONFIG_DIR" "$BACKUP_DIR"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << EOF
# LXC Manager Configuration
DEFAULT_STORAGE="$DEFAULT_STORAGE"
DEFAULT_NETWORK="$DEFAULT_NETWORK"
AUTO_BACKUP=$AUTO_BACKUP
NOTIFY=$NOTIFY
CPU_THRESHOLD=80
RAM_THRESHOLD=85
DISK_THRESHOLD=90
EOF
    fi
    
    source "$CONFIG_FILE"
}

# Logging
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case $level in
        "INFO") echo -e "${BLUE}[i]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[✓]${NC} $message" ;;
        "WARNING") echo -e "${YELLOW}[!]${NC} $message" ;;
        "ERROR") echo -e "${RED}[✗]${NC} $message" ;;
        *) echo -e "[$level] $message" ;;
    esac
}

# Check LXC Installation
check_lxc() {
    if ! command -v lxc &> /dev/null; then
        log "ERROR" "LXC/LXD is not installed!"
        echo -e "\n${YELLOW}Installing LXD...${NC}"
        
        # Detect OS and install
        if [[ -f /etc/debian_version ]]; then
            sudo apt update
            sudo apt install -y lxd lxd-client
        elif [[ -f /etc/redhat-release ]]; then
            sudo yum install -y epel-release
            sudo yum install -y lxd lxd-client
        elif [[ -f /etc/arch-release ]]; then
            sudo pacman -S --noconfirm lxd
        else
            echo "Please install LXD manually:"
            echo "  Snap: sudo snap install lxd"
            echo "  Manual: https://linuxcontainers.org/lxd/getting-started-cli/"
            exit 1
        fi
        
        # Initialize LXD
        echo -e "\n${YELLOW}Initializing LXD (press Enter for defaults)...${NC}"
        sudo lxd init --auto
        
        # Add user to lxd group
        sudo usermod -aG lxd $USER
        echo -e "\n${GREEN}Please logout and login again or run: newgrp lxd${NC}"
    fi
}

# Display Header
show_header() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║     ${WHITE}🚀 LXC CONTAINER MANAGEMENT SYSTEM${PURPLE}        ║${NC}"
    echo -e "${PURPLE}║     ${WHITE}     Version 2.0 - Bash Menu${PURPLE}             ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════╝${NC}"
    echo -e "${CYAN}$(date '+%Y-%m-%d %H:%M:%S')${NC} | User: ${BOLD}$USER${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# Main Menu
main_menu() {
    while true; do
        show_header
        echo -e "${WHITE}📋 MAIN MENU${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${GREEN}1.${NC} 📦 Container Management"
        echo -e "  ${GREEN}2.${NC} 🛠️  Resource Management"
        echo -e "  ${GREEN}3.${NC} 🌐 Network Management"
        echo -e "  ${GREEN}4.${NC} 💾 Storage Management"
        echo -e "  ${GREEN}5.${NC} 📊 System Monitoring"
        echo -e "  ${GREEN}6.${NC} ⚙️  Settings & Configuration"
        echo -e "  ${GREEN}7.${NC} 🔄 Backup & Restore"
        echo -e "  ${GREEN}8.${NC} 📝 View Logs"
        echo -e "  ${GREEN}9.${NC} 🚀 Quick Actions"
        echo -e "  ${GREEN}0.${NC} 🚪 Exit"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        read -p "$(echo -e "${YELLOW}Select option [0-9]: ${NC}")" choice
        
        case $choice in
            1) container_menu ;;
            2) resource_menu ;;
            3) network_menu ;;
            4) storage_menu ;;
            5) monitoring_menu ;;
            6) settings_menu ;;
            7) backup_menu ;;
            8) view_logs ;;
            9) quick_actions ;;
            0) exit_script ;;
            *) echo -e "${RED}Invalid option!${NC}"; sleep 1 ;;
        esac
    done
}

# Container Management Menu
container_menu() {
    while true; do
        show_header
        echo -e "${WHITE}📦 CONTAINER MANAGEMENT${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${GREEN}1.${NC} 🆕 Create New Container"
        echo -e "  ${GREEN}2.${NC} 📋 List All Containers"
        echo -e "  ${GREEN}3.${NC} ▶️  Start Container"
        echo -e "  ${GREEN}4.${NC} ⏹️  Stop Container"
        echo -e "  ${GREEN}5.${NC} 🔄 Restart Container"
        echo -e "  ${GREEN}6.${NC} 🗑️  Delete Container"
        echo -e "  ${GREEN}7.${NC} 📝 Container Info"
        echo -e "  ${GREEN}8.${NC} 🔧 Configure Container"
        echo -e "  ${GREEN}9.${NC} 💻 Enter Container Shell"
        echo -e "  ${GREEN}10.${NC} 📦 Clone Container"
        echo -e "  ${GREEN}11.${NC} 📤 Export Container"
        echo -e "  ${GREEN}12.${NC} 📥 Import Container"
        echo -e "  ${GREEN}0.${NC} ↩️  Back to Main Menu"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        read -p "$(echo -e "${YELLOW}Select option [0-12]: ${NC}")" choice
        
        case $choice in
            1) create_container ;;
            2) list_containers ;;
            3) start_container ;;
            4) stop_container ;;
            5) restart_container ;;
            6) delete_container ;;
            7) container_info ;;
            8) configure_container ;;
            9) enter_container ;;
            10) clone_container ;;
            11) export_container ;;
            12) import_container ;;
            0) return ;;
            *) echo -e "${RED}Invalid option!${NC}"; sleep 1 ;;
        esac
    done
}

# Create Container
create_container() {
    show_header
    echo -e "${WHITE}🆕 CREATE NEW CONTAINER${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Container Name
    read -p "$(echo -e "${YELLOW}Enter container name: ${NC}")" name
    if [[ -z "$name" ]]; then
        echo -e "${RED}Container name cannot be empty!${NC}"
        sleep 2
        return
    fi
    
    # Check if container exists
    if lxc list | grep -q "$name"; then
        echo -e "${RED}Container '$name' already exists!${NC}"
        sleep 2
        return
    fi
    
    # Select OS
    echo -e "\n${CYAN}Available OS Templates:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    for i in "${!OS_NAMES[@]}"; do
        echo -e "  ${GREEN}$i.${NC} ${OS_NAMES[$i]}"
    done
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    read -p "$(echo -e "${YELLOW}Select OS [1-${#OS_TEMPLATES[@]}]: ${NC}")" os_choice
    if [[ ! "${OS_TEMPLATES[$os_choice]}" ]]; then
        echo -e "${RED}Invalid OS selection!${NC}"
        sleep 2
        return
    fi
    os_image="${OS_TEMPLATES[$os_choice]}"
    
    # Resource Configuration
    echo -e "\n${CYAN}Resource Configuration:${NC}"
    read -p "$(echo -e "${YELLOW}CPU Cores (default: 1): ${NC}")" cpu
    cpu=${cpu:-1}
    
    read -p "$(echo -e "${YELLOW}RAM in MB (default: 1024): ${NC}")" memory
    memory=${memory:-1024}
    
    read -p "$(echo -e "${YELLOW}Disk Size in GB (default: 10): ${NC}")" disk
    disk=${disk:-10}
    
    # Network Configuration
    read -p "$(echo -e "${YELLOW}IPv4 Address (leave empty for DHCP): ${NC}")" ipv4
    
    # Additional Options
    echo -e "\n${CYAN}Additional Options:${NC}"
    read -p "$(echo -e "${YELLOW}Enable nesting? (y/n, default: n): ${NC}")" enable_nesting
    read -p "$(echo -e "${YELLOW}Enable privileged mode? (y/n, default: n): ${NC}")" enable_privileged
    
    # Confirmation
    echo -e "\n${YELLOW}Configuration Summary:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${CYAN}Name:${NC} $name"
    echo -e "  ${CYAN}OS:${NC} ${OS_NAMES[$os_choice]}"
    echo -e "  ${CYAN}CPU:${NC} $cpu cores"
    echo -e "  ${CYAN}RAM:${NC} $memory MB"
    echo -e "  ${CYAN}Disk:${NC} $disk GB"
    echo -e "  ${CYAN}IPv4:${NC} ${ipv4:-DHCP}"
    echo -e "  ${CYAN}Nesting:${NC} ${enable_nesting:-n}"
    echo -e "  ${CYAN}Privileged:${NC} ${enable_privileged:-n}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    read -p "$(echo -e "${YELLOW}Create container? (y/n): ${NC}")" confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        log "INFO" "Creating container: $name"
        
        # Create container
        echo -e "\n${CYAN}Creating container '$name'...${NC}"
        lxc launch "$os_image" "$name"
        
        # Configure resources
        lxc config set "$name" limits.cpu "$cpu"
        lxc config set "$name" limits.memory "${memory}MB"
        lxc config device override "$name" root size="${disk}GB"
        
        # Configure networking if IP specified
        if [[ -n "$ipv4" ]]; then
            lxc config device set "$name" eth0 ipv4.address="$ipv4"
        fi
        
        # Configure advanced options
        if [[ "$enable_nesting" =~ ^[Yy]$ ]]; then
            lxc config set "$name" security.nesting true
        fi
        
        if [[ "$enable_privileged" =~ ^[Yy]$ ]]; then
            lxc config set "$name" security.privileged true
        fi
        
        log "SUCCESS" "Container '$name' created successfully!"
        echo -e "${GREEN}✅ Container '$name' created successfully!${NC}"
        
        # Start container if not running
        lxc start "$name" 2>/dev/null
        
        # Show connection info
        echo -e "\n${YELLOW}Connection Information:${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${CYAN}To access container:${NC}"
        echo -e "  ${WHITE}lxc exec $name -- bash${NC}"
        echo -e "  ${WHITE}lxc console $name${NC}"
        
        # Get IP address
        container_ip=$(lxc list "$name" --format=csv | cut -d, -f4 | tail -1 | tr -d ' ')
        if [[ -n "$container_ip" ]]; then
            echo -e "\n  ${CYAN}IP Address:${NC} $container_ip"
            echo -e "  ${CYAN}SSH Access:${NC} ssh ubuntu@$container_ip"
        fi
    else
        echo -e "${YELLOW}Container creation cancelled.${NC}"
    fi
    
    read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
}

# List Containers
list_containers() {
    show_header
    echo -e "${WHITE}📋 CONTAINER LIST${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Detailed list with formatting
    echo -e "${CYAN}Fetching container information...${NC}\n"
    
    # Get container list in detailed format
    lxc list --format=table
    
    echo -e "\n${YELLOW}Quick Stats:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    total=$(lxc list --format=csv | wc -l)
    running=$(lxc list status=RUNNING --format=csv | wc -l)
    stopped=$(lxc list status=STOPPED --format=csv | wc -l)
    
    echo -e "  ${CYAN}Total Containers:${NC} $total"
    echo -e "  ${GREEN}Running:${NC} $running"
    echo -e "  ${RED}Stopped:${NC} $stopped"
    
    read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
}

# Start Container
start_container() {
    show_header
    echo -e "${WHITE}▶️ START CONTAINER${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Get stopped containers
    stopped_containers=$(lxc list status=STOPPED --format=csv | cut -d, -f1)
    
    if [[ -z "$stopped_containers" ]]; then
        echo -e "${YELLOW}No stopped containers found.${NC}"
        sleep 2
        return
    fi
    
    echo -e "${CYAN}Stopped Containers:${NC}\n"
    i=1
    declare -A container_map
    for container in $stopped_containers; do
        container=$(echo "$container" | xargs)
        container_map[$i]=$container
        echo -e "  ${GREEN}$i.${NC} $container"
        ((i++))
    done
    
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "$(echo -e "${YELLOW}Select container to start [1-$((i-1))] or 'all': ${NC}")" choice
    
    if [[ "$choice" == "all" ]]; then
        echo -e "\n${CYAN}Starting all containers...${NC}"
        for container in $stopped_containers; do
            container=$(echo "$container" | xargs)
            echo -e "  Starting $container..."
            lxc start "$container"
        done
        log "SUCCESS" "Started all containers"
        echo -e "${GREEN}✅ All containers started!${NC}"
    elif [[ -n "${container_map[$choice]}" ]]; then
        container="${container_map[$choice]}"
        echo -e "\n${CYAN}Starting container: $container${NC}"
        lxc start "$container"
        log "SUCCESS" "Started container: $container"
        echo -e "${GREEN}✅ Container '$container' started!${NC}"
    else
        echo -e "${RED}Invalid selection!${NC}"
    fi
    
    read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
}

# Stop Container
stop_container() {
    show_header
    echo -e "${WHITE}⏹️ STOP CONTAINER${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Get running containers
    running_containers=$(lxc list status=RUNNING --format=csv | cut -d, -f1)
    
    if [[ -z "$running_containers" ]]; then
        echo -e "${YELLOW}No running containers found.${NC}"
        sleep 2
        return
    fi
    
    echo -e "${CYAN}Running Containers:${NC}\n"
    i=1
    declare -A container_map
    for container in $running_containers; do
        container=$(echo "$container" | xargs)
        container_map[$i]=$container
        echo -e "  ${GREEN}$i.${NC} $container"
        ((i++))
    done
    
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "$(echo -e "${YELLOW}Select container to stop [1-$((i-1))] or 'all': ${NC}")" choice
    
    if [[ "$choice" == "all" ]]; then
        echo -e "\n${CYAN}Stopping all containers...${NC}"
        for container in $running_containers; do
            container=$(echo "$container" | xargs)
            echo -e "  Stopping $container..."
            lxc stop "$container"
        done
        log "SUCCESS" "Stopped all containers"
        echo -e "${GREEN}✅ All containers stopped!${NC}"
    elif [[ -n "${container_map[$choice]}" ]]; then
        container="${container_map[$choice]}"
        read -p "$(echo -e "${YELLOW}Force stop? (y/n): ${NC}")" force
        echo -e "\n${CYAN}Stopping container: $container${NC}"
        if [[ "$force" =~ ^[Yy]$ ]]; then
            lxc stop "$container" --force
        else
            lxc stop "$container"
        fi
        log "SUCCESS" "Stopped container: $container"
        echo -e "${GREEN}✅ Container '$container' stopped!${NC}"
    else
        echo -e "${RED}Invalid selection!${NC}"
    fi
    
    read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
}

# Restart Container
restart_container() {
    show_header
    echo -e "${WHITE}🔄 RESTART CONTAINER${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Get containers
    containers=$(lxc list --format=csv | cut -d, -f1)
    
    if [[ -z "$containers" ]]; then
        echo -e "${YELLOW}No containers found.${NC}"
        sleep 2
        return
    fi
    
    echo -e "${CYAN}Containers:${NC}\n"
    i=1
    declare -A container_map
    for container in $containers; do
        container=$(echo "$container" | xargs)
        container_map[$i]=$container
        status=$(lxc list "$container" --format=csv | cut -d, -f2 | xargs)
        echo -e "  ${GREEN}$i.${NC} $container (${status^^})"
        ((i++))
    done
    
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "$(echo -e "${YELLOW}Select container to restart [1-$((i-1))] or 'all': ${NC}")" choice
    
    if [[ "$choice" == "all" ]]; then
        echo -e "\n${CYAN}Restarting all containers...${NC}"
        for container in $containers; do
            container=$(echo "$container" | xargs)
            echo -e "  Restarting $container..."
            lxc restart "$container"
        done
        log "SUCCESS" "Restarted all containers"
        echo -e "${GREEN}✅ All containers restarted!${NC}"
    elif [[ -n "${container_map[$choice]}" ]]; then
        container="${container_map[$choice]}"
        read -p "$(echo -e "${YELLOW}Force restart? (y/n): ${NC}")" force
        echo -e "\n${CYAN}Restarting container: $container${NC}"
        if [[ "$force" =~ ^[Yy]$ ]]; then
            lxc restart "$container" --force
        else
            lxc restart "$container"
        fi
        log "SUCCESS" "Restarted container: $container"
        echo -e "${GREEN}✅ Container '$container' restarted!${NC}"
    else
        echo -e "${RED}Invalid selection!${NC}"
    fi
    
    read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
}

# Delete Container
delete_container() {
    show_header
    echo -e "${WHITE}🗑️ DELETE CONTAINER${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Get containers
    containers=$(lxc list --format=csv | cut -d, -f1)
    
    if [[ -z "$containers" ]]; then
        echo -e "${YELLOW}No containers found.${NC}"
        sleep 2
        return
    fi
    
    echo -e "${CYAN}Containers:${NC}\n"
    i=1
    declare -A container_map
    for container in $containers; do
        container=$(echo "$container" | xargs)
        container_map[$i]=$container
        status=$(lxc list "$container" --format=csv | cut -d, -f2 | xargs)
        echo -e "  ${GREEN}$i.${NC} $container (${status^^})"
        ((i++))
    done
    
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "$(echo -e "${YELLOW}Select container to delete [1-$((i-1))]: ${NC}")" choice
    
    if [[ -n "${container_map[$choice]}" ]]; then
        container="${container_map[$choice]}"
        
        # Warning
        echo -e "\n${RED}⚠️ WARNING: This will permanently delete container '$container'${NC}"
        echo -e "${RED}All data will be lost!${NC}"
        
        read -p "$(echo -e "${YELLOW}Are you sure? Type 'DELETE' to confirm: ${NC}")" confirm
        
        if [[ "$confirm" == "DELETE" ]]; then
            read -p "$(echo -e "${YELLOW}Force delete? (y/n): ${NC}")" force
            echo -e "\n${CYAN}Deleting container: $container${NC}"
            
            if [[ "$force" =~ ^[Yy]$ ]]; then
                lxc delete "$container" --force
            else
                lxc delete "$container"
            fi
            
            log "SUCCESS" "Deleted container: $container"
            echo -e "${GREEN}✅ Container '$container' deleted!${NC}"
        else
            echo -e "${YELLOW}Deletion cancelled.${NC}"
        fi
    else
        echo -e "${RED}Invalid selection!${NC}"
    fi
    
    read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
}

# Container Information
container_info() {
    show_header
    echo -e "${WHITE}📝 CONTAINER INFORMATION${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Get containers
    containers=$(lxc list --format=csv | cut -d, -f1)
    
    if [[ -z "$containers" ]]; then
        echo -e "${YELLOW}No containers found.${NC}"
        sleep 2
        return
    fi
    
    echo -e "${CYAN}Select Container:${NC}\n"
    i=1
    declare -A container_map
    for container in $containers; do
        container=$(echo "$container" | xargs)
        container_map[$i]=$container
        echo -e "  ${GREEN}$i.${NC} $container"
        ((i++))
    done
    
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "$(echo -e "${YELLOW}Select container [1-$((i-1))]: ${NC}")" choice
    
    if [[ -n "${container_map[$choice]}" ]]; then
        container="${container_map[$choice]}"
        
        echo -e "\n${CYAN}Fetching information for: $container${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # Get detailed info
        lxc info "$container"
        
        # Show additional info
        echo -e "\n${YELLOW}Additional Information:${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # Get IP address
        ip=$(lxc list "$container" --format=csv | cut -d, -f4 | xargs)
        echo -e "  ${CYAN}IP Address:${NC} $ip"
        
        # Get state
        state=$(lxc list "$container" --format=csv | cut -d, -f2 | xargs)
        echo -e "  ${CYAN}State:${NC} $state"
        
        # Get creation date
        created=$(lxc info "$container" | grep "Created:" | cut -d: -f2- | xargs)
        echo -e "  ${CYAN}Created:${NC} $created"
        
        # Get snapshots
        snapshots=$(lxc info "$container" | grep -A5 "Snapshots:" | tail -n +2)
        if [[ -n "$snapshots" ]]; then
            echo -e "  ${CYAN}Snapshots:${NC}"
            echo "$snapshots" | while read snap; do
                echo -e "    - $snap"
            done
        fi
    else
        echo -e "${RED}Invalid selection!${NC}"
    fi
    
    read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
}

# Enter Container Shell
enter_container() {
    show_header
    echo -e "${WHITE}💻 ENTER CONTAINER SHELL${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Get running containers
    running_containers=$(lxc list status=RUNNING --format=csv | cut -d, -f1)
    
    if [[ -z "$running_containers" ]]; then
        echo -e "${YELLOW}No running containers found.${NC}"
        sleep 2
        return
    fi
    
    echo -e "${CYAN}Running Containers:${NC}\n"
    i=1
    declare -A container_map
    for container in $running_containers; do
        container=$(echo "$container" | xargs)
        container_map[$i]=$container
        echo -e "  ${GREEN}$i.${NC} $container"
        ((i++))
    done
    
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "$(echo -e "${YELLOW}Select container [1-$((i-1))]: ${NC}")" choice
    
    if [[ -n "${container_map[$choice]}" ]]; then
        container="${container_map[$choice]}"
        
        echo -e "\n${CYAN}Entering container: $container${NC}"
        echo -e "${YELLOW}Type 'exit' to return to menu${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
        
        # Enter container
        lxc exec "$container" -- bash
    else
        echo -e "${RED}Invalid selection!${NC}"
    fi
    
    read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
}

# Clone Container
clone_container() {
    show_header
    echo -e "${WHITE}📦 CLONE CONTAINER${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Get containers
    containers=$(lxc list --format=csv | cut -d, -f1)
    
    if [[ -z "$containers" ]]; then
        echo -e "${YELLOW}No containers found.${NC}"
        sleep 2
        return
    fi
    
    echo -e "${CYAN}Source Containers:${NC}\n"
    i=1
    declare -A container_map
    for container in $containers; do
        container=$(echo "$container" | xargs)
        container_map[$i]=$container
        echo -e "  ${GREEN}$i.${NC} $container"
        ((i++))
    done
    
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "$(echo -e "${YELLOW}Select source container [1-$((i-1))]: ${NC}")" choice
    
    if [[ -n "${container_map[$choice]}" ]]; then
        source_container="${container_map[$choice]}"
        
        read -p "$(echo -e "${YELLOW}Enter name for new container: ${NC}")" new_name
        
        if [[ -z "$new_name" ]]; then
            echo -e "${RED}Container name cannot be empty!${NC}"
            sleep 2
            return
        fi
        
        # Check if new name exists
        if lxc list | grep -q "$new_name"; then
            echo -e "${RED}Container '$new_name' already exists!${NC}"
            sleep 2
            return
        fi
        
        echo -e "\n${CYAN}Cloning $source_container to $new_name...${NC}"
        
        # Clone container
        lxc copy "$source_container" "$new_name"
        
        # Start cloned container
        lxc start "$new_name"
        
        log "SUCCESS" "Cloned container: $source_container -> $new_name"
        echo -e "${GREEN}✅ Container cloned successfully!${NC}"
        echo -e "\n${CYAN}New container:${NC} $new_name"
        echo -e "${CYAN}Source container:${NC} $source_container"
    else
        echo -e "${RED}Invalid selection!${NC}"
    fi
    
    read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
}

# Export Container
export_container() {
    show_header
    echo -e "${WHITE}📤 EXPORT CONTAINER${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Get containers
    containers=$(lxc list --format=csv | cut -d, -f1)
    
    if [[ -z "$containers" ]]; then
        echo -e "${YELLOW}No containers found.${NC}"
        sleep 2
        return
    fi
    
    echo -e "${CYAN}Containers:${NC}\n"
    i=1
    declare -A container_map
    for container in $containers; do
        container=$(echo "$container" | xargs)
        container_map[$i]=$container
        echo -e "  ${GREEN}$i.${NC} $container"
        ((i++))
    done
    
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "$(echo -e "${YELLOW}Select container to export [1-$((i-1))]: ${NC}")" choice
    
    if [[ -n "${container_map[$choice]}" ]]; then
        container="${container_map[$choice]}"
        
        # Set export path
        export_dir="$BACKUP_DIR/exports"
        mkdir -p "$export_dir"
        export_file="$export_dir/${container}_$(date +%Y%m%d_%H%M%S).tar.gz"
        
        echo -e "\n${CYAN}Exporting container: $container${NC}"
        echo -e "${YELLOW}Export file: $export_file${NC}"
        
        # Export container
        lxc export "$container" "$export_file"
        
        if [[ $? -eq 0 ]]; then
            filesize=$(du -h "$export_file" | cut -f1)
            log "SUCCESS" "Exported container: $container -> $export_file"
            echo -e "${GREEN}✅ Container exported successfully!${NC}"
            echo -e "\n${CYAN}Export Details:${NC}"
            echo -e "  ${CYAN}File:${NC} $export_file"
            echo -e "  ${CYAN}Size:${NC} $filesize"
            echo -e "  ${CYAN}Date:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
        else
            echo -e "${RED}Export failed!${NC}"
        fi
    else
        echo -e "${RED}Invalid selection!${NC}"
    fi
    
    read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
}

# Import Container
import_container() {
    show_header
    echo -e "${WHITE}📥 IMPORT CONTAINER${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Check for export files
    export_dir="$BACKUP_DIR/exports"
    if [[ ! -d "$export_dir" ]]; then
        echo -e "${YELLOW}No export directory found.${NC}"
        sleep 2
        return
    fi
    
    export_files=$(ls "$export_dir"/*.tar.gz 2>/dev/null)
    
    if [[ -z "$export_files" ]]; then
        echo -e "${YELLOW}No export files found in $export_dir${NC}"
        sleep 2
        return
    fi
    
    echo -e "${CYAN}Export Files:${NC}\n"
    i=1
    declare -A file_map
    for file in $export_files; do
        file_map[$i]=$file
        filename=$(basename "$file")
        filesize=$(du -h "$file" | cut -f1)
        echo -e "  ${GREEN}$i.${NC} $filename ($filesize)"
        ((i++))
    done
    
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "$(echo -e "${YELLOW}Select file to import [1-$((i-1))]: ${NC}")" choice
    
    if [[ -n "${file_map[$choice]}" ]]; then
        export_file="${file_map[$choice]}"
        
        read -p "$(echo -e "${YELLOW}Enter name for imported container: ${NC}")" new_name
        
        if [[ -z "$new_name" ]]; then
            echo -e "${RED}Container name cannot be empty!${NC}"
            sleep 2
            return
        fi
        
        # Check if container exists
        if lxc list | grep -q "$new_name"; then
            echo -e "${RED}Container '$new_name' already exists!${NC}"
            sleep 2
            return
        fi
        
        echo -e "\n${CYAN}Importing container from: $(basename "$export_file")${NC}"
        echo -e "${CYAN}New container name: $new_name${NC}"
        
        # Import container
        lxc import "$export_file" --alias "$new_name"
        
        if [[ $? -eq 0 ]]; then
            log "SUCCESS" "Imported container: $new_name from $export_file"
            echo -e "${GREEN}✅ Container imported successfully!${NC}"
            
            # Start container
            read -p "$(echo -e "${YELLOW}Start container now? (y/n): ${NC}")" start_now
            if [[ "$start_now" =~ ^[Yy]$ ]]; then
                lxc start "$new_name"
                echo -e "${GREEN}Container '$new_name' started!${NC}"
            fi
        else
            echo -e "${RED}Import failed!${NC}"
        fi
    else
        echo -e "${RED}Invalid selection!${NC}"
    fi
    
    read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
}

# Resource Management Menu
resource_menu() {
    while true; do
        show_header
        echo -e "${WHITE}🛠️ RESOURCE MANAGEMENT${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${GREEN}1.${NC} 📊 View Resource Usage"
        echo -e "  ${GREEN}2.${NC} ⚡ Update Container Resources"
        echo -e "  ${GREEN}3.${NC} 📈 Set Resource Limits"
        echo -e "  ${GREEN}4.${NC} 🔄 Live Resource Monitor"
        echo -e "  ${GREEN}5.${NC} 📋 Resource Statistics"
        echo -e "  ${GREEN}0.${NC} ↩️ Back to Main Menu"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        read -p "$(echo -e "${YELLOW}Select option [0-5]: ${NC}")" choice
        
        case $choice in
            1) view_resource_usage ;;
            2) update_container_resources ;;
            3) set_resource_limits ;;
            4) live_resource_monitor ;;
            5) resource_statistics ;;
            0) return ;;
            *) echo -e "${RED}Invalid option!${NC}"; sleep 1 ;;
        esac
    done
}

# View Resource Usage
view_resource_usage() {
    show_header
    echo -e "${WHITE}📊 RESOURCE USAGE${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # System resources
    echo -e "${CYAN}System Resources:${NC}\n"
    
    # CPU
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    echo -e "  ${CYAN}CPU Usage:${NC} $cpu_usage%"
    
    # Memory
    mem_total=$(free -h | grep Mem | awk '{print $2}')
    mem_used=$(free -h | grep Mem | awk '{print $3}')
    mem_percent=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
    echo -e "  ${CYAN}Memory:${NC} $mem_used/$mem_total ($(printf "%.1f" "$mem_percent")%)"
    
    # Disk
    disk_total=$(df -h / | tail -1 | awk '{print $2}')
    disk_used=$(df -h / | tail -1 | awk '{print $3}')
    disk_percent=$(df / | tail -1 | awk '{print $5}')
    echo -e "  ${CYAN}Disk:${NC} $disk_used/$disk_total ($disk_percent)"
    
    echo -e "\n${CYAN}Container Resources:${NC}\n"
    
    # Container resources
    lxc list --format=table
    
    read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
}

# Update Container Resources
update_container_resources() {
    show_header
    echo -e "${WHITE}⚡ UPDATE CONTAINER RESOURCES${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Get containers
    containers=$(lxc list --format=csv | cut -d, -f1)
    
    if [[ -z "$containers" ]]; then
        echo -e "${YELLOW}No containers found.${NC}"
        sleep 2
        return
    fi
    
    echo -e "${CYAN}Select Container:${NC}\n"
    i=1
    declare -A container_map
    for container in $containers; do
        container=$(echo "$container" | xargs)
        container_map[$i]=$container
        echo -e "  ${GREEN}$i.${NC} $container"
        ((i++))
    done
    
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "$(echo -e "${YELLOW}Select container [1-$((i-1))]: ${NC}")" choice
    
    if [[ -n "${container_map[$choice]}" ]]; then
        container="${container_map[$choice]}"
        
        echo -e "\n${CYAN}Current Resources for: $container${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # Show current resources
        lxc config show "$container" | grep -E "(limits\.|root\.size)"
        
        echo -e "\n${CYAN}Update Resources:${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        read -p "$(echo -e "${YELLOW}New CPU cores (leave empty to keep current): ${NC}")" new_cpu
        read -p "$(echo -e "${YELLOW}New RAM in MB (leave empty to keep current): ${NC}")" new_ram
        read -p "$(echo -e "${YELLOW}New Disk size in GB (leave empty to keep current): ${NC}")" new_disk
        
        # Update CPU
        if [[ -n "$new_cpu" ]]; then
            lxc config set "$container" limits.cpu "$new_cpu"
            echo -e "${GREEN}✅ CPU updated to $new_cpu cores${NC}"
        fi
        
        # Update RAM
        if [[ -n "$new_ram" ]]; then
            lxc config set "$container" limits.memory "${new_ram}MB"
            echo -e "${GREEN}✅ RAM updated to $new_ram MB${NC}"
        fi
        
        # Update Disk
        if [[ -n "$new_disk" ]]; then
            lxc config device override "$container" root size="${new_disk}GB"
            echo -e "${GREEN}✅ Disk updated to $new_disk GB${NC}"
        fi
        
        if [[ -n "$new_cpu" ]] || [[ -n "$new_ram" ]] || [[ -n "$new_disk" ]]; then
            log "SUCCESS" "Updated resources for container: $container"
            echo -e "\n${GREEN}✅ Resources updated successfully!${NC}"
            
            # Restart container to apply changes
            read -p "$(echo -e "${YELLOW}Restart container to apply changes? (y/n): ${NC}")" restart_confirm
            if [[ "$restart_confirm" =~ ^[Yy]$ ]]; then
                lxc restart "$container"
                echo -e "${GREEN}Container restarted!${NC}"
            fi
        else
            echo -e "${YELLOW}No changes made.${NC}"
        fi
    else
        echo -e "${RED}Invalid selection!${NC}"
    fi
    
    read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
}

# Network Management Menu
network_menu() {
    while true; do
        show_header
        echo -e "${WHITE}🌐 NETWORK MANAGEMENT${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${GREEN}1.${NC} 📋 List Networks"
        echo -e "  ${GREEN}2.${NC} 🆕 Create Network"
        echo -e "  ${GREEN}3.${NC} 🗑️ Delete Network"
        echo -e "  ${GREEN}4.${NC} 🔧 Configure Network"
        echo -e "  ${GREEN}5.${NC} 📊 Network Information"
        echo -e "  ${GREEN}6.${NC} 🔗 Attach Container to Network"
        echo -e "  ${GREEN}7.${NC} 🔓 Detach Container from Network"
        echo -e "  ${GREEN}0.${NC} ↩️ Back to Main Menu"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        read -p "$(echo -e "${YELLOW}Select option [0-7]: ${NC}")" choice
        
        case $choice in
            1) list_networks ;;
            2) create_network ;;
            3) delete_network ;;
            4) configure_network ;;
            5) network_info ;;
            6) attach_network ;;
            7) detach_network ;;
            0) return ;;
            *) echo -e "${RED}Invalid option!${NC}"; sleep 1 ;;
        esac
    done
}

# List Networks
list_networks() {
    show_header
    echo -e "${WHITE}📋 NETWORK LIST${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo -e "${CYAN}Available Networks:${NC}\n"
    lxc network list --format=table
    
    read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
}

# Create Network
create_network() {
    show_header
    echo -e "${WHITE}🆕 CREATE NETWORK${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    read -p "$(echo -e "${YELLOW}Enter network name: ${NC}")" network_name
    
    if [[ -z "$network_name" ]]; then
        echo -e "${RED}Network name cannot be empty!${NC}"
        sleep 2
        return
    fi
    
    echo -e "\n${CYAN}Network Configuration:${NC}"
    read -p "$(echo -e "${YELLOW}Network type (bridge, physical, macvlan, sriov): ${NC}")" network_type
    network_type=${network_type:-bridge}
    
    read -p "$(echo -e "${YELLOW}IPv4 subnet (e.g., 10.10.10.1/24): ${NC}")" ipv4_subnet
    read -p "$(echo -e "${YELLOW}IPv6 subnet (leave empty for none): ${NC}")" ipv6_subnet
    read -p "$(echo -e "${YELLOW}DHCP range (e.g., 10.10.10.100-10.10.10.200): ${NC}")" dhcp_range
    
    echo -e "\n${CYAN}Creating network '$network_name'...${NC}"
    
    # Create network
    if lxc network create "$network_name" --type="$network_type"; then
        # Configure IPv4 if provided
        if [[ -n "$ipv4_subnet" ]]; then
            lxc network set "$network_name" ipv4.address "$ipv4_subnet"
        fi
        
        # Configure IPv6 if provided
        if [[ -n "$ipv6_subnet" ]]; then
            lxc network set "$network_name" ipv6.address "$ipv6_subnet"
        fi
        
        # Configure DHCP if provided
        if [[ -n "$dhcp_range" ]]; then
            lxc network set "$network_name" ipv4.dhcp.ranges "$dhcp_range"
        fi
        
        log "SUCCESS" "Created network: $network_name"
        echo -e "${GREEN}✅ Network '$network_name' created successfully!${NC}"
    else
        echo -e "${RED}Failed to create network!${NC}"
    fi
    
    read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
}

# Storage Management Menu
storage_menu() {
    while true; do
        show_header
        echo -e "${WHITE}💾 STORAGE MANAGEMENT${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${GREEN}1.${NC} 📋 List Storage Pools"
        echo -e "  ${GREEN}2.${NC} 🆕 Create Storage Pool"
        echo -e "  ${GREEN}3.${NC} 🗑️ Delete Storage Pool"
        echo -e "  ${GREEN}4.${NC} 📊 Storage Information"
        echo -e "  ${GREEN}5.${NC} 📁 List Storage Volumes"
        echo -e "  ${GREEN}6.${NC} 📦 Create Storage Volume"
        echo -e "  ${GREEN}7.${NC} 🗂️ Attach Storage Volume"
        echo -e "  ${GREEN}8.${NC} 🗑️ Delete Storage Volume"
        echo -e "  ${GREEN}0.${NC} ↩️ Back to Main Menu"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        read -p "$(echo -e "${YELLOW}Select option [0-8]: ${NC}")" choice
        
        case $choice in
            1) list_storage_pools ;;
            2) create_storage_pool ;;
            3) delete_storage_pool ;;
            4) storage_info ;;
            5) list_storage_volumes ;;
            6) create_storage_volume ;;
            7) attach_storage_volume ;;
            8) delete_storage_volume ;;
            0) return ;;
            *) echo -e "${RED}Invalid option!${NC}"; sleep 1 ;;
        esac
    done
}

# List Storage Pools
list_storage_pools() {
    show_header
    echo -e "${WHITE}📋 STORAGE POOLS${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo -e "${CYAN}Available Storage Pools:${NC}\n"
    lxc storage list --format=table
    
    read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
}

# System Monitoring Menu
monitoring_menu() {
    while true; do
        show_header
        echo -e "${WHITE}📊 SYSTEM MONITORING${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${GREEN}1.${NC} 📈 Live System Monitor"
        echo -e "  ${GREEN}2.${NC} 🔥 Container Performance"
        echo -e "  ${GREEN}3.${NC} 📊 Resource History"
        echo -e "  ${GREEN}4.${NC} ⚠️ Set Alerts"
        echo -e "  ${GREEN}5.${NC} 📋 View Logs"
        echo -e "  ${GREEN}0.${NC} ↩️ Back to Main Menu"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        read -p "$(echo -e "${YELLOW}Select option [0-5]: ${NC}")" choice
        
        case $choice in
            1) live_system_monitor ;;
            2) container_performance ;;
            3) resource_history ;;
            4) set_alerts ;;
            5) view_logs ;;
            0) return ;;
            *) echo -e "${RED}Invalid option!${NC}"; sleep 1 ;;
        esac
    done
}

# Live System Monitor
live_system_monitor() {
    show_header
    echo -e "${WHITE}📈 LIVE SYSTEM MONITOR${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo -e "${CYAN}Starting live monitor (Press Ctrl+C to exit)...${NC}\n"
    
    # Continuous monitoring
    while true; do
        clear
        show_header
        echo -e "${WHITE}📈 LIVE SYSTEM MONITOR${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # System stats
        echo -e "${CYAN}System Resources:${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # CPU
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
        echo -e "  ${CYAN}CPU:${NC} [$(progress_bar "$cpu_usage")] ${cpu_usage}%"
        
        # Memory
        mem_percent=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
        mem_used=$(free -h | grep Mem | awk '{print $3}')
        mem_total=$(free -h | grep Mem | awk '{print $2}')
        echo -e "  ${CYAN}RAM:${NC} [$(progress_bar "$mem_percent")] ${mem_used}/${mem_total} ($(printf "%.1f" "$mem_percent")%)"
        
        # Disk
        disk_percent=$(df / --output=pcent | tail -1 | tr -d ' %')
        disk_used=$(df -h / --output=used | tail -1)
        disk_total=$(df -h / --output=size | tail -1)
        echo -e "  ${CYAN}Disk:${NC} [$(progress_bar "$disk_percent")] ${disk_used}/${disk_total} (${disk_percent}%)"
        
        # Load average
        load=$(cat /proc/loadavg | awk '{print $1", "$2", "$3}')
        echo -e "  ${CYAN}Load:${NC} $load"
        
        # Uptime
        uptime=$(uptime -p)
        echo -e "  ${CYAN}Uptime:${NC} $uptime"
        
        echo -e "\n${CYAN}Container Status:${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # Container summary
        total=$(lxc list --format=csv | wc -l)
        running=$(lxc list status=RUNNING --format=csv | wc -l)
        stopped=$(lxc list status=STOPPED --format=csv | wc -l)
        
        echo -e "  ${CYAN}Total:${NC} $total  ${GREEN}Running:${NC} $running  ${RED}Stopped:${NC} $stopped"
        
        # Quick container list
        echo -e "\n  ${CYAN}Top 5 Containers by CPU:${NC}"
        lxc list --format=csv | head -6 | while IFS=, read -r name status ip4 ip6 type description; do
            if [[ "$name" != "NAME" ]]; then
                echo -e "    ${GREEN}▶${NC} $(echo $name | xargs) - $(echo $status | xargs)"
            fi
        done
        
        echo -e "\n${YELLOW}Press Ctrl+C to exit live monitor${NC}"
        sleep 2
    done
}

# Progress bar for visualization
progress_bar() {
    local percent=$1
    local filled=$(echo "scale=0; $percent/5" | bc)
    local empty=$((20 - filled))
    
    printf "["
    for ((i=0; i<filled; i++)); do printf "█"; done
    for ((i=0; i<empty; i++)); do printf "░"; done
    printf "]"
}

# Settings Menu
settings_menu() {
    while true; do
        show_header
        echo -e "${WHITE}⚙️ SETTINGS & CONFIGURATION${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${GREEN}1.${NC} 📊 Configure Thresholds"
        echo -e "  ${GREEN}2.${NC} 🔔 Notification Settings"
        echo -e "  ${GREEN}3.${NC} 💾 Backup Settings"
        echo -e "  ${GREEN}4.${NC} 🌐 Network Settings"
        echo -e "  ${GREEN}5.${NC} 🔧 LXD Configuration"
        echo -e "  ${GREEN}6.${NC} 📝 Edit Config File"
        echo -e "  ${GREEN}7.${NC} 🗑️ Reset Configuration"
        echo -e "  ${GREEN}0.${NC} ↩️ Back to Main Menu"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        read -p "$(echo -e "${YELLOW}Select option [0-7]: ${NC}")" choice
        
        case $choice in
            1) configure_thresholds ;;
            2) notification_settings ;;
            3) backup_settings ;;
            4) network_settings ;;
            5) lxd_configuration ;;
            6) edit_config_file ;;
            7) reset_configuration ;;
            0) return ;;
            *) echo -e "${RED}Invalid option!${NC}"; sleep 1 ;;
        esac
    done
}

# Backup Menu
backup_menu() {
    while true; do
        show_header
        echo -e "${WHITE}🔄 BACKUP & RESTORE${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${GREEN}1.${NC} 💾 Backup Container"
        echo -e "  ${GREEN}2.${NC} 📥 Restore Container"
        echo -e "  ${GREEN}3.${NC} 📋 List Backups"
        echo -e "  ${GREEN}4.${NC} 🗑️ Delete Backup"
        echo -e "  ${GREEN}5.${NC} ⏰ Schedule Backups"
        echo -e "  ${GREEN}6.${NC} 🌐 Remote Backup"
        echo -e "  ${GREEN}0.${NC} ↩️ Back to Main Menu"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        read -p "$(echo -e "${YELLOW}Select option [0-6]: ${NC}")" choice
        
        case $choice in
            1) backup_container ;;
            2) restore_container ;;
            3) list_backups ;;
            4) delete_backup ;;
            5) schedule_backups ;;
            6) remote_backup ;;
            0) return ;;
            *) echo -e "${RED}Invalid option!${NC}"; sleep 1 ;;
        esac
    done
}

# Quick Actions Menu
quick_actions() {
    while true; do
        show_header
        echo -e "${WHITE}🚀 QUICK ACTIONS${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${GREEN}1.${NC} ⚡ Quick Start All"
        echo -e "  ${GREEN}2.${NC} ⏹️ Quick Stop All"
        echo -e "  ${GREEN}3.${NC} 🔄 Restart All"
        echo -e "  ${GREEN}4.${NC} 📊 Quick Stats"
        echo -e "  ${GREEN}5.${NC} 🧹 Cleanup Old Images"
        echo -e "  ${GREEN}6.${NC} 🔍 Find Large Containers"
        echo -e "  ${GREEN}7.${NC} 🚀 Performance Boost"
        echo -e "  ${GREEN}8.${NC} 🛡️ Security Check"
        echo -e "  ${GREEN}0.${NC} ↩️ Back to Main Menu"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        read -p "$(echo -e "${YELLOW}Select option [0-8]: ${NC}")" choice
        
        case $choice in
            1) quick_start_all ;;
            2) quick_stop_all ;;
            3) quick_restart_all ;;
            4) quick_stats ;;
            5) cleanup_old_images ;;
            6) find_large_containers ;;
            7) performance_boost ;;
            8) security_check ;;
            0) return ;;
            *) echo -e "${RED}Invalid option!${NC}"; sleep 1 ;;
        esac
    done
}

# Quick Start All Containers
quick_start_all() {
    show_header
    echo -e "${WHITE}⚡ QUICK START ALL CONTAINERS${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    stopped_count=$(lxc list status=STOPPED --format=csv | wc -l)
    
    if [[ $stopped_count -eq 0 ]]; then
        echo -e "${YELLOW}All containers are already running!${NC}"
        read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
        return
    fi
    
    echo -e "${CYAN}Found $stopped_count stopped containers${NC}\n"
    
    echo -e "${YELLOW}Starting all containers...${NC}"
    for container in $(lxc list status=STOPPED --format=csv | cut -d, -f1); do
        container=$(echo "$container" | xargs)
        echo -e "  ${GREEN}▶${NC} Starting $container"
        lxc start "$container" 2>/dev/null
    done
    
    log "SUCCESS" "Started all containers"
    echo -e "\n${GREEN}✅ All containers started successfully!${NC}"
    
    read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
}

# View Logs
view_logs() {
    show_header
    echo -e "${WHITE}📝 SYSTEM LOGS${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo -e "${CYAN}Select Log File:${NC}"
    echo -e "  ${GREEN}1.${NC} LXC Manager Logs"
    echo -e "  ${GREEN}2.${NC} LXD Daemon Logs"
    echo -e "  ${GREEN}3.${NC} System Journal"
    echo -e "  ${GREEN}4.${NC} Auth Log"
    echo -e "  ${GREEN}5.${NC} Kernel Log"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    read -p "$(echo -e "${YELLOW}Select log [1-5]: ${NC}")" log_choice
    
    case $log_choice in
        1)
            echo -e "\n${CYAN}LXC Manager Logs:${NC}"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            tail -50 "$LOG_FILE"
            ;;
        2)
            echo -e "\n${CYAN}LXD Daemon Logs:${NC}"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            sudo journalctl -u lxd -n 50
            ;;
        3)
            echo -e "\n${CYAN}System Journal:${NC}"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            sudo journalctl -n 50
            ;;
        4)
            echo -e "\n${CYAN}Auth Log:${NC}"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            sudo tail -50 /var/log/auth.log 2>/dev/null || echo "Auth log not found"
            ;;
        5)
            echo -e "\n${CYAN}Kernel Log:${NC}"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            sudo dmesg -T | tail -50
            ;;
        *)
            echo -e "${RED}Invalid selection!${NC}"
            ;;
    esac
    
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "$(echo -e "${YELLOW}Press Enter to continue...${NC}")"
}

# Exit Script
exit_script() {
    echo -e "\n${CYAN}Thank you for using LXC Manager!${NC}"
    echo -e "${PURPLE}Goodbye! 👋${NC}\n"
    exit 0
}

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Cleaning up...${NC}"
    # Add any cleanup code here
    exit 0
}

# Trap Ctrl+C
trap cleanup SIGINT

# Main execution
init_system
check_lxc
main_menu
