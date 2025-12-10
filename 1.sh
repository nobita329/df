#!/bin/bash

# ==============================================
# LXC Manager Complete with IPv4/IPv6 & Network Fix
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

# Default Settings
DEFAULT_STORAGE="default"
DEFAULT_NETWORK="lxdbr0"
IPV4_SUBNET="10.10.10.1/24"
IPV6_SUBNET="fd42:abcd:1234::1/64"

# OS Templates
declare -A OS_TEMPLATES=(
    [1]="ubuntu:20.04"
    [2]="ubuntu:22.04"
    [3]="ubuntu:24.04"
    [4]="debian:11"
    [5]="debian:12"
    [6]="centos:7"
    [7]="alpine/edge"
    [8]="archlinux"
)

declare -A OS_NAMES=(
    [1]="Ubuntu 20.04 LTS"
    [2]="Ubuntu 22.04 LTS"
    [3]="Ubuntu 24.04 LTS"
    [4]="Debian 11 Bullseye"
    [5]="Debian 12 Bookworm"
    [6]="CentOS 7"
    [7]="Alpine Linux Edge"
    [8]="Arch Linux"
)

# Initialize
init_system() {
    mkdir -p "$CONFIG_DIR"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << EOF
DEFAULT_STORAGE="$DEFAULT_STORAGE"
DEFAULT_NETWORK="$DEFAULT_NETWORK"
IPV4_SUBNET="$IPV4_SUBNET"
IPV6_SUBNET="$IPV6_SUBNET"
EOF
    fi
    
    source "$CONFIG_FILE"
}

# Logging
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Display Header
show_header() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║     ${WHITE}🚀 LXC MANAGER WITH IPv4/IPv6 SUPPORT${PURPLE}          ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════╝${NC}"
    echo -e "${CYAN}Date: $(date '+%Y-%m-%d %H:%M:%S')${NC} | ${CYAN}User: $USER${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# Fix Network Issues
fix_network_issues() {
    echo -e "\n${YELLOW}🛠️ FIXING NETWORK ISSUES${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Check DNS
    echo -e "${CYAN}Checking DNS configuration...${NC}"
    
    # Fix DNS in container
    fix_container_dns() {
        local container=$1
        echo -e "  Fixing DNS in ${GREEN}$container${NC}"
        
        lxc exec "$container" -- bash -c "
            # Backup original resolv.conf
            cp /etc/resolv.conf /etc/resolv.conf.backup
            
            # Set Google DNS
            echo 'nameserver 8.8.8.8' > /etc/resolv.conf
            echo 'nameserver 8.8.4.4' >> /etc/resolv.conf
            echo 'nameserver 1.1.1.1' >> /etc/resolv.conf
            
            # For Ubuntu/Debian
            if [ -f /etc/netplan/ ]; then
                echo 'network:' > /etc/netplan/01-netcfg.yaml
                echo '  version: 2' >> /etc/netplan/01-netcfg.yaml
                echo '  ethernets:' >> /etc/netplan/01-netcfg.yaml
                echo '    eth0:' >> /etc/netplan/01-netcfg.yaml
                echo '      dhcp4: true' >> /etc/netplan/01-netcfg.yaml
                echo '      dhcp6: true' >> /etc/netplan/01-netcfg.yaml
                echo '      nameservers:' >> /etc/netplan/01-netcfg.yaml
                echo '        addresses: [8.8.8.8, 8.8.4.4, 1.1.1.1]' >> /etc/netplan/01-netcfg.yaml
                netplan apply
            fi
            
            # For CentOS/RHEL
            if [ -f /etc/sysconfig/network-scripts/ ]; then
                echo 'DNS1=8.8.8.8' >> /etc/sysconfig/network-scripts/ifcfg-eth0
                echo 'DNS2=8.8.4.4' >> /etc/sysconfig/network-scripts/ifcfg-eth0
                systemctl restart network
            fi
            
            echo 'DNS fixed successfully'
        " 2>/dev/null
    }
    
    # Get all containers
    containers=$(lxc list --format csv 2>/dev/null | cut -d',' -f1)
    
    if [[ -n "$containers" ]]; then
        for container in $containers; do
            container=$(echo "$container" | xargs)
            if lxc info "$container" 2>/dev/null | grep -q "Status: Running"; then
                fix_container_dns "$container"
            fi
        done
    fi
    
    # Fix host DNS
    echo -e "\n${CYAN}Fixing host DNS...${NC}"
    sudo bash -c "
        echo 'nameserver 8.8.8.8' > /etc/resolv.conf
        echo 'nameserver 8.8.4.4' >> /etc/resolv.conf
        echo 'nameserver 1.1.1.1' >> /etc/resolv.conf
    "
    
    # Restart networking
    sudo systemctl restart systemd-resolved 2>/dev/null || true
    
    echo -e "\n${GREEN}✅ Network issues fixed!${NC}"
    read -p "$(echo -e "${YELLOW}Press Enter to continue...${NC}")"
}

# Create Container with IPv4/IPv6
create_container() {
    show_header
    echo -e "${WHITE}📦 CREATE CONTAINER WITH IPv4/IPv6${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Get container name
    while true; do
        read -p "$(echo -e "${YELLOW}Enter container name: ${NC}")" name
        if [[ -z "$name" ]]; then
            echo -e "${RED}Container name cannot be empty!${NC}"
            continue
        fi
        
        # Check if exists
        if lxc list --format csv 2>/dev/null | grep -q "^$name,"; then
            echo -e "${RED}Container '$name' already exists!${NC}"
            continue
        fi
        
        break
    done
    
    # Select OS
    echo -e "\n${CYAN}Select OS:${NC}"
    for i in {1..8}; do
        echo -e "  ${GREEN}$i.${NC} ${OS_NAMES[$i]}"
    done
    
    while true; do
        read -p "$(echo -e "${YELLOW}Choose OS [1-8]: ${NC}")" os_choice
        if [[ -n "${OS_TEMPLATES[$os_choice]}" ]]; then
            os_image="${OS_TEMPLATES[$os_choice]}"
            break
        else
            echo -e "${RED}Invalid choice!${NC}"
        fi
    done
    
    # IPv4 Configuration
    echo -e "\n${CYAN}IPv4 Configuration:${NC}"
    echo -e "  1. DHCP (Automatic)"
    echo -e "  2. Static IP"
    echo -e "  3. No IPv4"
    
    read -p "$(echo -e "${YELLOW}Choose IPv4 option [1-3]: ${NC}")" ipv4_choice
    
    case $ipv4_choice in
        1) ipv4_config="dhcp" ;;
        2)
            read -p "$(echo -e "${YELLOW}Enter IPv4 address (e.g., 10.10.10.100): ${NC}")" ipv4_static
            ipv4_config="static:$ipv4_static"
            ;;
        3) ipv4_config="none" ;;
        *) ipv4_config="dhcp" ;;
    esac
    
    # IPv6 Configuration
    echo -e "\n${CYAN}IPv6 Configuration:${NC}"
    echo -e "  1. Auto (SLAAC)"
    echo -e "  2. Static IPv6"
    echo -e "  3. No IPv6"
    
    read -p "$(echo -e "${YELLOW}Choose IPv6 option [1-3]: ${NC}")" ipv6_choice
    
    case $ipv6_choice in
        1) ipv6_config="auto" ;;
        2)
            read -p "$(echo -e "${YELLOW}Enter IPv6 address (e.g., fd42:abcd:1234::100): ${NC}")" ipv6_static
            ipv6_config="static:$ipv6_static"
            ;;
        3) ipv6_config="none" ;;
        *) ipv6_config="auto" ;;
    esac
    
    # Resources
    echo -e "\n${CYAN}Resource Configuration:${NC}"
    read -p "$(echo -e "${YELLOW}CPU cores (default: 2): ${NC}")" cpu
    cpu=${cpu:-2}
    
    read -p "$(echo -e "${YELLOW}RAM in MB (default: 2048): ${NC}")" memory
    memory=${memory:-2048}
    
    read -p "$(echo -e "${YELLOW}Disk in GB (default: 20): ${NC}")" disk
    disk=${disk:-20}
    
    # Create container
    echo -e "\n${CYAN}Creating container '$name'...${NC}"
    
    # Launch container
    if ! lxc launch "$os_image" "$name"; then
        echo -e "${RED}Failed to launch container!${NC}"
        echo -e "${YELLOW}Checking LXD configuration...${NC}"
        
        # Fix LXD if needed
        lxc storage create default dir 2>/dev/null || true
        lxc profile device add default root disk path=/ pool=default 2>/dev/null || true
        
        # Try again
        if ! lxc launch "$os_image" "$name"; then
            echo -e "${RED}Still failed. Please check LXD.${NC}"
            sleep 2
            return
        fi
    fi
    
    # Configure resources
    lxc config set "$name" limits.cpu "$cpu"
    lxc config set "$name" limits.memory "${memory}MB"
    lxc config device override "$name" root size="${disk}GB"
    
    # Configure networking
    if [[ "$ipv4_config" != "none" ]]; then
        if [[ "$ipv4_config" == "dhcp" ]]; then
            echo -e "${GREEN}IPv4: DHCP enabled${NC}"
        else
            static_ip=$(echo "$ipv4_config" | cut -d':' -f2)
            lxc config device set "$name" eth0 ipv4.address="$static_ip"
            echo -e "${GREEN}IPv4: Static $static_ip${NC}"
        fi
    fi
    
    if [[ "$ipv6_config" != "none" ]]; then
        if [[ "$ipv6_config" == "auto" ]]; then
            echo -e "${GREEN}IPv6: Auto configuration${NC}"
        else
            static_ipv6=$(echo "$ipv6_config" | cut -d':' -f2)
            lxc config device set "$name" eth0 ipv6.address="$static_ipv6"
            echo -e "${GREEN}IPv6: Static $static_ipv6${NC}"
        fi
    fi
    
    # Enable features
    lxc config set "$name" security.nesting true
    lxc config set "$name" security.privileged true
    
    # Fix DNS immediately
    echo -e "\n${CYAN}Fixing DNS in container...${NC}"
    lxc exec "$name" -- bash -c "
        echo 'nameserver 8.8.8.8' > /etc/resolv.conf
        echo 'nameserver 8.8.4.4' >> /etc/resolv.conf
        echo 'nameserver 1.1.1.1' >> /etc/resolv.conf
    "
    
    echo -e "\n${GREEN}✅ Container '$name' created successfully!${NC}"
    
    # Show connection info
    echo -e "\n${CYAN}Connection Information:${NC}"
    echo -e "  Shell: ${YELLOW}lxc exec $name -- bash${NC}"
    echo -e "  Console: ${YELLOW}lxc console $name${NC}"
    
    # Get IP addresses
    sleep 3
    ipv4_addr=$(lxc list "$name" --format csv | cut -d',' -f4 | xargs)
    ipv6_addr=$(lxc list "$name" --format csv | cut -d',' -f5 | xargs)
    
    if [[ -n "$ipv4_addr" ]]; then
        echo -e "  IPv4: ${GREEN}$ipv4_addr${NC}"
    fi
    if [[ -n "$ipv6_addr" ]]; then
        echo -e "  IPv6: ${GREEN}$ipv6_addr${NC}"
    fi
    
    read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
}

# List Containers with Details
list_containers() {
    show_header
    echo -e "${WHITE}📋 CONTAINER LIST WITH DETAILS${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if ! lxc list --format table; then
        echo -e "${YELLOW}No containers found or LXD not running.${NC}"
    fi
    
    # Summary
    echo -e "\n${CYAN}Summary:${NC}"
    total=$(lxc list --format csv 2>/dev/null | wc -l)
    running=$(lxc list status=RUNNING --format csv 2>/dev/null | wc -l)
    
    echo -e "  Total Containers: $total"
    echo -e "  Running: ${GREEN}$running${NC}"
    echo -e "  Stopped: ${RED}$((total - running))${NC}"
    
    read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
}

# Edit Container Configuration
edit_container() {
    show_header
    echo -e "${WHITE}✏️ EDIT CONTAINER CONFIGURATION${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Get containers
    containers=$(lxc list --format csv 2>/dev/null | cut -d',' -f1)
    
    if [[ -z "$containers" ]]; then
        echo -e "${YELLOW}No containers found.${NC}"
        sleep 2
        return
    fi
    
    echo -e "${CYAN}Select Container:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    i=1
    declare -A container_map
    for container in $containers; do
        container=$(echo "$container" | xargs)
        container_map[$i]=$container
        echo -e "  ${GREEN}$i.${NC} $container"
        ((i++))
    done
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "$(echo -e "${YELLOW}Select container [1-$((i-1))]: ${NC}")" choice
    
    if [[ -n "${container_map[$choice]}" ]]; then
        container="${container_map[$choice]}"
        
        while true; do
            show_header
            echo -e "${WHITE}Editing: $container${NC}"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "  ${GREEN}1.${NC} Change IPv4 Address"
            echo -e "  ${GREEN}2.${NC} Change IPv6 Address"
            echo -e "  ${GREEN}3.${NC} Change CPU Cores"
            echo -e "  ${GREEN}4.${NC} Change RAM"
            echo -e "  ${GREEN}5.${NC} Change Disk Size"
            echo -e "  ${GREEN}6.${NC} Change Network Settings"
            echo -e "  ${GREEN}7.${NC} View Current Config"
            echo -e "  ${GREEN}8.${NC} Fix DNS/Network"
            echo -e "  ${GREEN}0.${NC} Back to Main Menu"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            
            read -p "$(echo -e "${YELLOW}Select option [0-8]: ${NC}")" edit_choice
            
            case $edit_choice in
                1)
                    echo -e "\n${CYAN}Current IPv4:${NC}"
                    lxc list "$container" --format csv | cut -d',' -f4 | xargs
                    read -p "$(echo -e "${YELLOW}New IPv4 (leave empty for DHCP): ${NC}")" new_ipv4
                    if [[ -n "$new_ipv4" ]]; then
                        lxc config device set "$container" eth0 ipv4.address="$new_ipv4"
                        echo -e "${GREEN}✅ IPv4 updated!${NC}"
                    else
                        lxc config device set "$container" eth0 ipv4.address=""
                        echo -e "${GREEN}✅ IPv4 set to DHCP${NC}"
                    fi
                    ;;
                2)
                    echo -e "\n${CYAN}Current IPv6:${NC}"
                    lxc list "$container" --format csv | cut -d',' -f5 | xargs
                    read -p "$(echo -e "${YELLOW}New IPv6 (leave empty for auto): ${NC}")" new_ipv6
                    if [[ -n "$new_ipv6" ]]; then
                        lxc config device set "$container" eth0 ipv6.address="$new_ipv6"
                        echo -e "${GREEN}✅ IPv6 updated!${NC}"
                    else
                        lxc config device set "$container" eth0 ipv6.address=""
                        echo -e "${GREEN}✅ IPv6 set to auto${NC}"
                    fi
                    ;;
                3)
                    current_cpu=$(lxc config get "$container" limits.cpu)
                    echo -e "\n${CYAN}Current CPU: $current_cpu${NC}"
                    read -p "$(echo -e "${YELLOW}New CPU cores: ${NC}")" new_cpu
                    lxc config set "$container" limits.cpu "$new_cpu"
                    echo -e "${GREEN}✅ CPU updated to $new_cpu cores${NC}"
                    ;;
                4)
                    current_ram=$(lxc config get "$container" limits.memory)
                    echo -e "\n${CYAN}Current RAM: $current_ram${NC}"
                    read -p "$(echo -e "${YELLOW}New RAM in MB: ${NC}")" new_ram
                    lxc config set "$container" limits.memory "${new_ram}MB"
                    echo -e "${GREEN}✅ RAM updated to ${new_ram}MB${NC}"
                    ;;
                5)
                    current_disk=$(lxc config get "$container" root.size)
                    echo -e "\n${CYAN}Current Disk: $current_disk${NC}"
                    read -p "$(echo -e "${YELLOW}New Disk in GB: ${NC}")" new_disk
                    lxc config device override "$container" root size="${new_disk}GB"
                    echo -e "${GREEN}✅ Disk updated to ${new_disk}GB${NC}"
                    ;;
                6)
                    echo -e "\n${CYAN}Network Configuration:${NC}"
                    lxc config device show "$container" eth0
                    ;;
                7)
                    echo -e "\n${CYAN}Current Configuration:${NC}"
                    lxc config show "$container"
                    ;;
                8)
                    echo -e "\n${CYAN}Fixing DNS/Network...${NC}"
                    lxc exec "$container" -- bash -c "
                        echo 'nameserver 8.8.8.8' > /etc/resolv.conf
                        echo 'nameserver 8.8.4.4' >> /etc/resolv.conf
                        echo 'nameserver 1.1.1.1' >> /etc/resolv.conf
                        systemctl restart systemd-resolved 2>/dev/null || true
                        echo 'Network fixed!'
                    "
                    echo -e "${GREEN}✅ Network fixed!${NC}"
                    ;;
                0) break ;;
                *) echo -e "${RED}Invalid option!${NC}" ;;
            esac
            
            read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
        done
    else
        echo -e "${RED}Invalid selection!${NC}"
        sleep 2
    fi
}

# LXC Info with Details
lxc_info() {
    show_header
    echo -e "${WHITE}📊 LXC SYSTEM INFORMATION${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo -e "${CYAN}LXD Version:${NC}"
    lxd --version 2>/dev/null || echo "Not installed"
    
    echo -e "\n${CYAN}System Information:${NC}"
    lxc info
    
    echo -e "\n${CYAN}Storage Pools:${NC}"
    lxc storage list
    
    echo -e "\n${CYAN}Networks:${NC}"
    lxc network list
    
    echo -e "\n${CYAN}Profiles:${NC}"
    lxc profile list
    
    echo -e "\n${CYAN}Images:${NC}"
    lxc image list
    
    read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
}

# Multiple Container Operations
multi_container_ops() {
    show_header
    echo -e "${WHITE}👥 MULTIPLE CONTAINER OPERATIONS${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo -e "  ${GREEN}1.${NC} Start All Containers"
    echo -e "  ${GREEN}2.${NC} Stop All Containers"
    echo -e "  ${GREEN}3.${NC} Restart All Containers"
    echo -e "  ${GREEN}4.${NC} Fix DNS in All Containers"
    echo -e "  ${GREEN}5.${NC} Update All Containers"
    echo -e "  ${GREEN}6.${NC} Backup All Containers"
    echo -e "  ${GREEN}0.${NC} Back to Main Menu"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    read -p "$(echo -e "${YELLOW}Select option [0-6]: ${NC}")" multi_choice
    
    case $multi_choice in
        1)
            echo -e "\n${CYAN}Starting all containers...${NC}"
            for container in $(lxc list --format csv 2>/dev/null | cut -d',' -f1); do
                container=$(echo "$container" | xargs)
                if lxc info "$container" 2>/dev/null | grep -q "Status: Stopped"; then
                    echo -e "  Starting $container"
                    lxc start "$container"
                fi
            done
            echo -e "${GREEN}✅ All containers started!${NC}"
            ;;
        2)
            echo -e "\n${CYAN}Stopping all containers...${NC}"
            for container in $(lxc list --format csv 2>/dev/null | cut -d',' -f1); do
                container=$(echo "$container" | xargs)
                if lxc info "$container" 2>/dev/null | grep -q "Status: Running"; then
                    echo -e "  Stopping $container"
                    lxc stop "$container"
                fi
            done
            echo -e "${GREEN}✅ All containers stopped!${NC}"
            ;;
        3)
            echo -e "\n${CYAN}Restarting all containers...${NC}"
            for container in $(lxc list --format csv 2>/dev/null | cut -d',' -f1); do
                container=$(echo "$container" | xargs)
                echo -e "  Restarting $container"
                lxc restart "$container"
            done
            echo -e "${GREEN}✅ All containers restarted!${NC}"
            ;;
        4)
            echo -e "\n${CYAN}Fixing DNS in all containers...${NC}"
            for container in $(lxc list --format csv 2>/dev/null | cut -d',' -f1); do
                container=$(echo "$container" | xargs)
                if lxc info "$container" 2>/dev/null | grep -q "Status: Running"; then
                    echo -e "  Fixing DNS in $container"
                    lxc exec "$container" -- bash -c "
                        echo 'nameserver 8.8.8.8' > /etc/resolv.conf
                        echo 'nameserver 8.8.4.4' >> /etc/resolv.conf
                        echo 'nameserver 1.1.1.1' >> /etc/resolv.conf
                    " 2>/dev/null
                fi
            done
            echo -e "${GREEN}✅ DNS fixed in all containers!${NC}"
            ;;
        5)
            echo -e "\n${CYAN}Updating all containers...${NC}"
            for container in $(lxc list --format csv 2>/dev/null | cut -d',' -f1); do
                container=$(echo "$container" | xargs)
                if lxc info "$container" 2>/dev/null | grep -q "Status: Running"; then
                    echo -e "\n${YELLOW}Updating $container${NC}"
                    lxc exec "$container" -- bash -c "
                        if command -v apt-get &> /dev/null; then
                            apt-get update && apt-get upgrade -y
                        elif command -v yum &> /dev/null; then
                            yum update -y
                        elif command -v apk &> /dev/null; then
                            apk update && apk upgrade
                        elif command -v pacman &> /dev/null; then
                            pacman -Syu --noconfirm
                        fi
                    " 2>/dev/null
                fi
            done
            echo -e "${GREEN}✅ All containers updated!${NC}"
            ;;
        6)
            echo -e "\n${CYAN}Backing up all containers...${NC}"
            backup_dir="$HOME/lxc_backups_$(date +%Y%m%d_%H%M%S)"
            mkdir -p "$backup_dir"
            
            for container in $(lxc list --format csv 2>/dev/null | cut -d',' -f1); do
                container=$(echo "$container" | xargs)
                echo -e "  Backing up $container"
                lxc export "$container" "$backup_dir/${container}.tar.gz" 2>/dev/null
            done
            
            echo -e "${GREEN}✅ All containers backed up to: $backup_dir${NC}"
            ;;
        0) return ;;
        *) echo -e "${RED}Invalid option!${NC}" ;;
    esac
    
    read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
}

# Add Container to Network
add_to_network() {
    show_header
    echo -e "${WHITE}🌐 ADD CONTAINER TO NETWORK${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Get containers
    containers=$(lxc list --format csv 2>/dev/null | cut -d',' -f1)
    
    if [[ -z "$containers" ]]; then
        echo -e "${YELLOW}No containers found.${NC}"
        sleep 2
        return
    fi
    
    echo -e "${CYAN}Select Container:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    i=1
    declare -A container_map
    for container in $containers; do
        container=$(echo "$container" | xargs)
        container_map[$i]=$container
        echo -e "  ${GREEN}$i.${NC} $container"
        ((i++))
    done
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "$(echo -e "${YELLOW}Select container [1-$((i-1))]: ${NC}")" choice
    
    if [[ -n "${container_map[$choice]}" ]]; then
        container="${container_map[$choice]}"
        
        echo -e "\n${CYAN}Available Networks:${NC}"
        lxc network list --format csv | cut -d',' -f1
        
        read -p "$(echo -e "${YELLOW}Enter network name: ${NC}")" network_name
        
        # Add network interface
        lxc network attach "$network_name" "$container" eth1
        
        echo -e "\n${CYAN}Network Configuration:${NC}"
        read -p "$(echo -e "${YELLOW}IPv4 for eth1 (leave empty for DHCP): ${NC}")" eth1_ipv4
        read -p "$(echo -e "${YELLOW}IPv6 for eth1 (leave empty for auto): ${NC}")" eth1_ipv6
        
        if [[ -n "$eth1_ipv4" ]]; then
            lxc config device set "$container" eth1 ipv4.address="$eth1_ipv4"
        fi
        
        if [[ -n "$eth1_ipv6" ]]; then
            lxc config device set "$container" eth1 ipv6.address="$eth1_ipv6"
        fi
        
        echo -e "${GREEN}✅ Container added to network!${NC}"
        
        # Restart container to apply changes
        read -p "$(echo -e "${YELLOW}Restart container to apply changes? (y/N): ${NC}")" restart_choice
        if [[ "$restart_choice" =~ ^[Yy]$ ]]; then
            lxc restart "$container"
            echo -e "${GREEN}Container restarted!${NC}"
        fi
    else
        echo -e "${RED}Invalid selection!${NC}"
    fi
    
    read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
}

# Main Menu
main_menu() {
    while true; do
        show_header
        echo -e "${WHITE}📋 MAIN MENU${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${GREEN}1.${NC} 📦 Create Container (IPv4/IPv6)"
        echo -e "  ${GREEN}2.${NC} 📋 List Containers"
        echo -e "  ${GREEN}3.${NC} ✏️  Edit Container Config"
        echo -e "  ${GREEN}4.${NC} 📊 LXC System Info"
        echo -e "  ${GREEN}5.${NC} 👥 Multiple Container Operations"
        echo -e "  ${GREEN}6.${NC} 🌐 Add to Network"
        echo -e "  ${GREEN}7.${NC} 🛠️  Fix Network Issues"
        echo -e "  ${GREEN}8.${NC} ⚙️  Settings"
        echo -e "  ${GREEN}0.${NC} 🚪 Exit"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        read -p "$(echo -e "${YELLOW}Select option [0-8]: ${NC}")" choice
        
        case $choice in
            1) create_container ;;
            2) list_containers ;;
            3) edit_container ;;
            4) lxc_info ;;
            5) multi_container_ops ;;
            6) add_to_network ;;
            7) fix_network_issues ;;
            8) settings_menu ;;
            0)
                echo -e "\n${GREEN}Goodbye! 👋${NC}\n"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

# Settings Menu
settings_menu() {
    while true; do
        show_header
        echo -e "${WHITE}⚙️ SETTINGS${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${GREEN}1.${NC} View Configuration"
        echo -e "  ${GREEN}2.${NC} Edit Configuration"
        echo -e "  ${GREEN}3.${NC} Reset Configuration"
        echo -e "  ${GREEN}4.${NC} View Logs"
        echo -e "  ${GREEN}5.${NC} Clear Logs"
        echo -e "  ${GREEN}6.${NC} Check LXD Status"
        echo -e "  ${GREEN}7.${NC} Install/Update LXD"
        echo -e "  ${GREEN}0.${NC} Back to Main Menu"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        read -p "$(echo -e "${YELLOW}Select option [0-7]: ${NC}")" settings_choice
        
        case $settings_choice in
            1)
                echo -e "\n${CYAN}Current Configuration:${NC}"
                cat "$CONFIG_FILE"
                ;;
            2)
                nano "$CONFIG_FILE"
                source "$CONFIG_FILE"
                echo -e "${GREEN}✅ Configuration reloaded!${NC}"
                ;;
            3)
                rm -f "$CONFIG_FILE"
                init_system
                echo -e "${GREEN}✅ Configuration reset!${NC}"
                ;;
            4)
                echo -e "\n${CYAN}Log File:${NC}"
                tail -50 "$LOG_FILE"
                ;;
            5)
                > "$LOG_FILE"
                echo -e "${GREEN}✅ Logs cleared!${NC}"
                ;;
            6)
                echo -e "\n${CYAN}LXD Status:${NC}"
                systemctl status lxd --no-pager -l
                ;;
            7)
                echo -e "\n${CYAN}Installing/Updating LXD...${NC}"
                sudo snap install lxd --classic
                sudo lxd init --auto
                echo -e "${GREEN}✅ LXD installed/updated!${NC}"
                ;;
            0) return ;;
            *) echo -e "${RED}Invalid option!${NC}" ;;
        esac
        
        read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
    done
}

# Check LXD Installation
check_lxd() {
    if ! command -v lxd &> /dev/null; then
        echo -e "${RED}LXD is not installed!${NC}"
        echo -e "${YELLOW}Would you like to install it? (y/N): ${NC}"
        read -r install_lxd
        
        if [[ "$install_lxd" =~ ^[Yy]$ ]]; then
            echo -e "${CYAN}Installing LXD...${NC}"
            sudo snap install lxd --classic
            sudo lxd init --auto
            
            # Add user to lxd group
            sudo usermod -aG lxd $USER
            echo -e "${GREEN}✅ LXD installed!${NC}"
            echo -e "${YELLOW}Please logout and login again or run: newgrp lxd${NC}"
            exit 0
        else
            echo -e "${RED}LXD is required for this script. Exiting.${NC}"
            exit 1
        fi
    fi
    
    # Check if user is in lxd group
    if ! groups $USER | grep -q lxd; then
        echo -e "${YELLOW}User not in lxd group. Adding...${NC}"
        sudo usermod -aG lxd $USER
        echo -e "${GREEN}✅ User added to lxd group!${NC}"
        echo -e "${YELLOW}Please run: newgrp lxd${NC}"
        echo -e "${YELLOW}Then run this script again.${NC}"
        exit 0
    fi
}

# Start Script
init_system
check_lxd
main_menu
