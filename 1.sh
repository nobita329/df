#!/bin/bash
set -euo pipefail

# =============================
# Enhanced LXC Container Manager
# =============================

# Function to display header
display_header() {
    clear
    cat << "EOF"
██╗     ██╗  ██╗ ██████╗      ███╗   ███╗ █████╗ ███╗   ██╗ █████╗  ██████╗ ███████╗██████╗ 
██║     ██║  ██║██╔═══██╗     ████╗ ████║██╔══██╗████╗  ██║██╔══██╗██╔════╝ ██╔════╝██╔══██╗
██║     ███████║██║   ██║     ██╔████╔██║███████║██╔██╗ ██║███████║██║  ███╗█████╗  ██████╔╝
██║     ██╔══██║██║   ██║     ██║╚██╔╝██║██╔══██║██║╚██╗██║██╔══██║██║   ██║██╔══╝  ██╔══██╗
███████╗██║  ██║╚██████╔╝     ██║ ╚═╝ ██║██║  ██║██║ ╚████║██║  ██║╚██████╔╝███████╗██║  ██║
╚══════╝╚═╝  ╚═╝ ╚═════╝      ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝
EOF
    echo
}

# Function to display colored output with emojis
print_status() {
    local type=$1
    local message=$2
    
    case $type in
        "INFO") echo -e "\033[1;34m📋 [INFO]\033[0m $message" ;;
        "WARN") echo -e "\033[1;33m⚠️  [WARN]\033[0m $message" ;;
        "ERROR") echo -e "\033[1;31m❌ [ERROR]\033[0m $message" ;;
        "SUCCESS") echo -e "\033[1;32m✅ [SUCCESS]\033[0m $message" ;;
        "INPUT") echo -e "\033[1;36m🎯 [INPUT]\033[0m $message" ;;
        *) echo "[$type] $message" ;;
    esac
}

# Function to validate input
validate_input() {
    local type=$1
    local value=$2
    
    case $type in
        "number")
            if ! [[ "$value" =~ ^[0-9]+$ ]]; then
                print_status "ERROR" "❌ Must be a number"
                return 1
            fi
            ;;
        "size_mb")
            if ! [[ "$value" =~ ^[0-9]+$ ]]; then
                print_status "ERROR" "❌ Must be a number (in MB)"
                return 1
            fi
            ;;
        "size_gb")
            if ! [[ "$value" =~ ^[0-9]+$ ]]; then
                print_status "ERROR" "❌ Must be a number (in GB)"
                return 1
            fi
            ;;
        "port")
            if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 23 ] || [ "$value" -gt 65535 ]; then
                print_status "ERROR" "❌ Must be a valid port number (23-65535)"
                return 1
            fi
            ;;
        "name")
            if ! [[ "$value" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                print_status "ERROR" "❌ Container name can only contain letters, numbers, hyphens, and underscores"
                return 1
            fi
            ;;
        "ipv4")
            if ! [[ "$value" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && [[ "$value" != "dhcp" ]] && [[ -n "$value" ]]; then
                print_status "ERROR" "❌ Must be a valid IPv4 address or 'dhcp'"
                return 1
            fi
            ;;
        "ipv6")
            if ! [[ "$value" =~ ^[0-9a-fA-F:]+$ ]] && [[ "$value" != "auto" ]] && [[ -n "$value" ]]; then
                print_status "ERROR" "❌ Must be a valid IPv6 address or 'auto'"
                return 1
            fi
            ;;
    esac
    return 0
}

# Function to check dependencies
check_dependencies() {
    local deps=("lxc" "lxd" "wget" "curl" "lsof")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_status "ERROR" "🔧 Missing dependencies: ${missing_deps[*]}"
        print_status "INFO" "💡 On Ubuntu/Debian, try: sudo apt install lxd lxd-client wget curl lsof"
        
        read -p "$(print_status "INPUT" "🔧 Install missing dependencies now? (y/N): ")" install_deps
        if [[ "$install_deps" =~ ^[Yy]$ ]]; then
            sudo apt update
            sudo apt install -y lxd lxd-client wget curl lsof
            sudo lxd init --auto
            sudo usermod -aG lxd $USER
            print_status "SUCCESS" "✅ Dependencies installed! Please logout and login again or run: newgrp lxd"
            exit 0
        else
            exit 1
        fi
    fi
}

# Function to cleanup temporary files
cleanup() {
    # Cleanup any temporary files
    rm -f /tmp/lxc_*.tmp 2>/dev/null
}

# Function to get all LXC containers
get_container_list() {
    lxc list --format csv 2>/dev/null | cut -d',' -f1 | sort || echo ""
}

# Function to load container configuration
load_container_config() {
    local container_name=$1
    
    # Clear previous variables
    unset CONTAINER_NAME OS_TYPE DISK_SIZE_MB DISK_SIZE_GB MEMORY CPUS IPV4_ADDRESS IPV6_ADDRESS
    unset STATUS CREATED PRIVILEGED NESTING DNS_SERVERS STORAGE_POOL
    
    # Get container info
    if lxc info "$container_name" &>/dev/null; then
        CONTAINER_NAME="$container_name"
        OS_TYPE=$(lxc config get "$container_name" image.description 2>/dev/null || echo "Unknown")
        
        # Get disk size correctly
        local root_size=$(lxc config device get "$container_name" root size 2>/dev/null || echo "")
        if [[ -n "$root_size" ]]; then
            if [[ "$root_size" == *GB ]]; then
                DISK_SIZE_GB=$(echo "$root_size" | sed 's/GB//')
                DISK_SIZE_MB=$((DISK_SIZE_GB * 1024))
            elif [[ "$root_size" == *MB ]]; then
                DISK_SIZE_MB=$(echo "$root_size" | sed 's/MB//')
                DISK_SIZE_GB=$((DISK_SIZE_MB / 1024))
            else
                DISK_SIZE_GB=10
                DISK_SIZE_MB=10240
            fi
        else
            DISK_SIZE_GB=10
            DISK_SIZE_MB=10240
        fi
        
        MEMORY=$(lxc config get "$container_name" limits.memory 2>/dev/null | sed 's/MB//' || echo "1024")
        CPUS=$(lxc config get "$container_name" limits.cpu 2>/dev/null || echo "1")
        IPV4_ADDRESS=$(lxc list "$container_name" --format csv 2>/dev/null | cut -d',' -f4 | xargs)
        IPV6_ADDRESS=$(lxc list "$container_name" --format csv 2>/dev/null | cut -d',' -f5 | xargs)
        STATUS=$(lxc list "$container_name" --format csv 2>/dev/null | cut -d',' -f2 | xargs)
        CREATED=$(lxc info "$container_name" | grep "Created:" | cut -d: -f2- | xargs)
        PRIVILEGED=$(lxc config get "$container_name" security.privileged 2>/dev/null || echo "false")
        NESTING=$(lxc config get "$container_name" security.nesting 2>/dev/null || echo "false")
        DNS_SERVERS=$(lxc config device get "$container_name" eth0 dns.servers 2>/dev/null || echo "8.8.8.8,8.8.4.4")
        STORAGE_POOL=$(lxc storage list --format csv 2>/dev/null | grep "$CONTAINER_NAME" | cut -d',' -f1 || echo "default")
        
        return 0
    else
        print_status "ERROR" "📦 Container '$container_name' not found"
        return 1
    fi
}

# Function to create new container
create_new_container() {
    print_status "INFO" "🆕 Creating a new LXC Container"
    
    # OS Selection
    print_status "INFO" "🌍 Select an OS to set up:"
    local os_options=()
    local i=1
    for os in "${!OS_OPTIONS[@]}"; do
        echo "  $i) $os"
        os_options[$i]="$os"
        ((i++))
    done
    
    while true; do
        read -p "$(print_status "INPUT" "🎯 Enter your choice (1-${#OS_OPTIONS[@]}): ")" choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#OS_OPTIONS[@]} ]; then
            local os="${os_options[$choice]}"
            IFS='|' read -r OS_TYPE IMAGE_NAME DEFAULT_HOSTNAME <<< "${OS_OPTIONS[$os]}"
            break
        else
            print_status "ERROR" "❌ Invalid selection. Try again."
        fi
    done

    # Container name
    while true; do
        read -p "$(print_status "INPUT" "🏷️  Enter container name (default: $DEFAULT_HOSTNAME): ")" CONTAINER_NAME
        CONTAINER_NAME="${CONTAINER_NAME:-$DEFAULT_HOSTNAME}"
        if validate_input "name" "$CONTAINER_NAME"; then
            # Check if container already exists
            if lxc list --format csv 2>/dev/null | grep -q "^$CONTAINER_NAME,"; then
                print_status "ERROR" "⚠️  Container with name '$CONTAINER_NAME' already exists"
            else
                break
            fi
        fi
    done

    # Resource Configuration - FIXED: Ask for GB instead of G
    while true; do
        read -p "$(print_status "INPUT" "💾 Disk size in GB (default: 10): ")" DISK_SIZE_GB
        DISK_SIZE_GB="${DISK_SIZE_GB:-10}"
        if validate_input "size_gb" "$DISK_SIZE_GB"; then
            DISK_SIZE_MB=$((DISK_SIZE_GB * 1024))
            break
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "🧠 Memory in MB (default: 1024): ")" MEMORY
        MEMORY="${MEMORY:-1024}"
        if validate_input "size_mb" "$MEMORY"; then
            break
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "⚡ Number of CPUs (default: 1): ")" CPUS
        CPUS="${CPUS:-1}"
        if validate_input "number" "$CPUS"; then
            break
        fi
    done

    # Network Configuration
    print_status "INFO" "🌐 Network Configuration"
    
    # Check if network exists
    if ! lxc network list --format csv 2>/dev/null | grep -q "lxdbr0"; then
        print_status "WARN" "🌐 Default network 'lxdbr0' not found"
        read -p "$(print_status "INPUT" "🌐 Create default network 'lxdbr0'? (Y/n): ")" create_network
        if [[ "$create_network" =~ ^[Yy]$ ]] || [[ -z "$create_network" ]]; then
            lxc network create lxdbr0
            print_status "SUCCESS" "✅ Created network 'lxdbr0'"
        fi
    fi

    while true; do
        read -p "$(print_status "INPUT" "🔌 IPv4 Address (leave empty for DHCP, 'none' to disable): ")" IPV4_ADDRESS
        IPV4_ADDRESS="${IPV4_ADDRESS:-dhcp}"
        if validate_input "ipv4" "$IPV4_ADDRESS"; then
            break
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "🔌 IPv6 Address (leave empty for auto, 'none' to disable): ")" IPV6_ADDRESS
        IPV6_ADDRESS="${IPV6_ADDRESS:-auto}"
        if validate_input "ipv6" "$IPV6_ADDRESS"; then
            break
        fi
    done

    # Advanced Options
    print_status "INFO" "⚙️ Advanced Options"
    
    while true; do
        read -p "$(print_status "INPUT" "🛡️  Enable privileged mode? (y/N, default: N): ")" priv_input
        priv_input="${priv_input:-n}"
        if [[ "$priv_input" =~ ^[Yy]$ ]]; then 
            PRIVILEGED="true"
            break
        elif [[ "$priv_input" =~ ^[Nn]$ ]]; then
            PRIVILEGED="false"
            break
        else
            print_status "ERROR" "❌ Please answer y or n"
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "🐳 Enable nesting (for Docker/LXC inside)? (y/N, default: N): ")" nest_input
        nest_input="${nest_input:-n}"
        if [[ "$nest_input" =~ ^[Yy]$ ]]; then 
            NESTING="true"
            break
        elif [[ "$nest_input" =~ ^[Nn]$ ]]; then
            NESTING="false"
            break
        else
            print_status "ERROR" "❌ Please answer y or n"
        fi
    done

    # DNS Configuration
    read -p "$(print_status "INPUT" "🌐 DNS Servers (comma separated, default: 8.8.8.8,8.8.4.4): ")" DNS_SERVERS
    DNS_SERVERS="${DNS_SERVERS:-8.8.8.8,8.8.4.4}"

    CREATED="$(date)"
    STATUS="STOPPED"
    STORAGE_POOL="default"

    # Create and setup container
    setup_container
    
    # Save configuration
    save_container_config "$CONTAINER_NAME"
}

# Function to setup container - FIXED VERSION
setup_container() {
    print_status "INFO" "📥 Creating container '$CONTAINER_NAME'..."
    
    # Check storage pool
    if ! lxc storage list --format csv 2>/dev/null | grep -q "$STORAGE_POOL"; then
        print_status "WARN" "💾 Storage pool '$STORAGE_POOL' not found, creating..."
        lxc storage create "$STORAGE_POOL" dir
    fi
    
    # Check default profile
    if ! lxc profile show default 2>/dev/null | grep -q "root:"; then
        print_status "INFO" "⚙️  Configuring default profile..."
        lxc profile device add default root disk path=/ pool="$STORAGE_POOL"
    fi
    
    # Create container with explicit storage pool
    print_status "INFO" "🚀 Launching $OS_TYPE container..."
    if ! lxc launch "$IMAGE_NAME" "$CONTAINER_NAME" --storage "$STORAGE_POOL"; then
        print_status "ERROR" "❌ Failed to launch container. Trying alternative method..."
        
        # Alternative method
        lxc init "$IMAGE_NAME" "$CONTAINER_NAME" --storage "$STORAGE_POOL"
        if [[ $? -eq 0 ]]; then
            lxc start "$CONTAINER_NAME"
        else
            print_status "ERROR" "❌ Still failed. Please check LXD installation."
            exit 1
        fi
    fi
    
    # Configure resources - FIXED: Use correct format for disk size
    print_status "INFO" "⚙️  Configuring resources..."
    
    # Set CPU
    lxc config set "$CONTAINER_NAME" limits.cpu "$CPUS"
    
    # Set Memory (in MB)
    lxc config set "$CONTAINER_NAME" limits.memory "${MEMORY}MB"
    
    # Set Disk size - CORRECT FORMAT: Use number without GB/MB suffix
    lxc config device set "$CONTAINER_NAME" root size="${DISK_SIZE_GB}GB"
    
    # Configure advanced options
    lxc config set "$CONTAINER_NAME" security.privileged "$PRIVILEGED"
    lxc config set "$CONTAINER_NAME" security.nesting "$NESTING"
    
    # Configure DNS on host side
    if [[ -n "$DNS_SERVERS" ]]; then
        lxc config device set "$CONTAINER_NAME" eth0 dns.servers="$DNS_SERVERS"
    fi
    
    # Fix DNS inside container
    print_status "INFO" "🔧 Fixing DNS inside container..."
    lxc exec "$CONTAINER_NAME" -- bash -c "
        # Set DNS
        echo 'nameserver 8.8.8.8' > /etc/resolv.conf
        echo 'nameserver 8.8.4.4' >> /etc/resolv.conf
        echo 'nameserver 1.1.1.1' >> /etc/resolv.conf
        
        # For Ubuntu/Debian
        if [ -f /usr/bin/apt-get ]; then
            # Update package lists
            apt-get update 2>/dev/null || true
            
            # Fix network configuration if netplan exists
            if [ -d /etc/netplan ]; then
                cat > /etc/netplan/01-netcfg.yaml << 'EOF'
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      dhcp6: true
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4, 1.1.1.1]
EOF
                netplan apply 2>/dev/null || true
            fi
        fi
        
        # For CentOS/RHEL
        if [ -f /usr/bin/yum ]; then
            if [ -f /etc/sysconfig/network-scripts/ifcfg-eth0 ]; then
                echo 'DNS1=8.8.8.8' >> /etc/sysconfig/network-scripts/ifcfg-eth0
                echo 'DNS2=8.8.4.4' >> /etc/sysconfig/network-scripts/ifcfg-eth0
                systemctl restart network 2>/dev/null || true
            fi
        fi
    " 2>/dev/null || print_status "WARN" "⚠️  Could not configure DNS inside container (container may still be booting)"
    
    # Restart container to apply changes
    print_status "INFO" "🔄 Restarting container to apply configurations..."
    lxc restart "$CONTAINER_NAME"
    
    print_status "SUCCESS" "🎉 Container '$CONTAINER_NAME' created successfully!"
    
    # Wait for IP assignment
    print_status "INFO" "⏳ Waiting for network configuration..."
    sleep 5
    
    # Show connection info
    print_status "INFO" "🔌 Connection Information:"
    echo "  🐚 Shell: ${YELLOW}lxc exec $CONTAINER_NAME -- bash${NC}"
    echo "  📺 Console: ${YELLOW}lxc console $CONTAINER_NAME${NC}"
    echo "  📊 Info: ${YELLOW}lxc info $CONTAINER_NAME${NC}"
    
    # Get IP addresses
    local max_attempts=10
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        IPV4_ADDRESS=$(lxc list "$CONTAINER_NAME" --format csv 2>/dev/null | cut -d',' -f4 | xargs)
        IPV6_ADDRESS=$(lxc list "$CONTAINER_NAME" --format csv 2>/dev/null | cut -d',' -f5 | xargs)
        
        if [[ -n "$IPV4_ADDRESS" ]] || [[ -n "$IPV6_ADDRESS" ]]; then
            break
        fi
        
        print_status "INFO" "⏳ Waiting for IP address ($attempt/$max_attempts)..."
        sleep 2
        ((attempt++))
    done
    
    if [[ -n "$IPV4_ADDRESS" ]]; then
        echo "  🌐 IPv4: ${GREEN}$IPV4_ADDRESS${NC}"
        echo "  🔗 SSH: ${YELLOW}ssh ubuntu@$IPV4_ADDRESS${NC}"
    else
        echo "  🌐 IPv4: ${YELLOW}Not assigned yet${NC}"
    fi
    
    if [[ -n "$IPV6_ADDRESS" ]]; then
        echo "  🌐 IPv6: ${GREEN}$IPV6_ADDRESS${NC}"
    fi
    
    echo ""
    print_status "INFO" "📋 Container Details:"
    echo "  💾 Disk: ${DISK_SIZE_GB}GB"
    echo "  🧠 RAM: ${MEMORY}MB"
    echo "  ⚡ CPU: ${CPUS} cores"
    echo "  🛡️  Privileged: $PRIVILEGED"
    echo "  🐳 Nesting: $NESTING"
}

# Function to save container configuration
save_container_config() {
    local container_name=$1
    local config_file="$CONFIG_DIR/$container_name.conf"
    
    cat > "$config_file" <<EOF
CONTAINER_NAME="$CONTAINER_NAME"
OS_TYPE="$OS_TYPE"
IMAGE_NAME="$IMAGE_NAME"
DISK_SIZE_GB="$DISK_SIZE_GB"
DISK_SIZE_MB="$DISK_SIZE_MB"
MEMORY="$MEMORY"
CPUS="$CPUS"
IPV4_ADDRESS="$IPV4_ADDRESS"
IPV6_ADDRESS="$IPV6_ADDRESS"
STATUS="$STATUS"
CREATED="$CREATED"
PRIVILEGED="$PRIVILEGED"
NESTING="$NESTING"
DNS_SERVERS="$DNS_SERVERS"
STORAGE_POOL="$STORAGE_POOL"
EOF
    
    print_status "SUCCESS" "💾 Configuration saved to $config_file"
}

# Function to start a container
start_container() {
    local container_name=$1
    
    if load_container_config "$container_name"; then
        if [[ "$STATUS" == "RUNNING" ]]; then
            print_status "WARN" "⚠️  Container '$container_name' is already running"
            read -p "$(print_status "INPUT" "🔄 Stop and restart? (y/N): ")" restart_choice
            if [[ "$restart_choice" =~ ^[Yy]$ ]]; then
                stop_container "$container_name"
                sleep 2
            else
                return 1
            fi
        fi
        
        print_status "INFO" "🚀 Starting container: $container_name"
        
        if ! lxc start "$container_name"; then
            print_status "ERROR" "❌ Failed to start container"
            
            # Try to fix common issues
            print_status "INFO" "🔧 Trying to fix container..."
            
            # Check if storage pool exists
            if ! lxc storage list --format csv 2>/dev/null | grep -q "$STORAGE_POOL"; then
                print_status "INFO" "💾 Creating missing storage pool: $STORAGE_POOL"
                lxc storage create "$STORAGE_POOL" dir
            fi
            
            # Try starting again
            if lxc start "$container_name"; then
                print_status "SUCCESS" "✅ Container started after fixes"
            else
                return 1
            fi
        else
            print_status "SUCCESS" "✅ Container '$container_name' started"
        fi
        
        # Update status
        STATUS="RUNNING"
        save_container_config "$container_name"
        
        # Show IP address
        sleep 2
        IPV4_ADDRESS=$(lxc list "$container_name" --format csv 2>/dev/null | cut -d',' -f4 | xargs)
        if [[ -n "$IPV4_ADDRESS" ]]; then
            echo "  🌐 IP Address: ${GREEN}$IPV4_ADDRESS${NC}"
            echo "  🔗 SSH: ${YELLOW}ssh ubuntu@$IPV4_ADDRESS${NC}"
        fi
    fi
}

# Function to stop a container
stop_container() {
    local container_name=$1
    
    if load_container_config "$container_name"; then
        if [[ "$STATUS" != "RUNNING" ]]; then
            print_status "INFO" "💤 Container '$container_name' is not running"
            return 0
        fi
        
        print_status "INFO" "🛑 Stopping container: $container_name"
        
        # Ask for force stop
        read -p "$(print_status "INPUT" "⚡ Force stop? (y/N): ")" force_stop
        
        if [[ "$force_stop" =~ ^[Yy]$ ]]; then
            lxc stop "$container_name" --force
        else
            lxc stop "$container_name"
        fi
        
        if [[ $? -eq 0 ]]; then
            STATUS="STOPPED"
            save_container_config "$container_name"
            print_status "SUCCESS" "✅ Container '$container_name' stopped"
        else
            print_status "ERROR" "❌ Failed to stop container"
            return 1
        fi
    fi
}

# Function to delete a container
delete_container() {
    local container_name=$1
    
    print_status "WARN" "⚠️  ⚠️  ⚠️  This will permanently delete container '$container_name' and all its data!"
    read -p "$(print_status "INPUT" "🗑️  Are you sure? (y/N): ")" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if load_container_config "$container_name"; then
            # Check if container is running
            if [[ "$STATUS" == "RUNNING" ]]; then
                print_status "WARN" "⚠️  Container is currently running. Stopping it first..."
                stop_container "$container_name"
                sleep 2
            fi
            
            # Delete container
            lxc delete "$container_name" --force
            
            # Delete configuration file
            rm -f "$CONFIG_DIR/$container_name.conf" 2>/dev/null
            
            print_status "SUCCESS" "✅ Container '$container_name' has been deleted"
        fi
    else
        print_status "INFO" "👍 Deletion cancelled"
    fi
}

# Function to show container info
show_container_info() {
    local container_name=$1
    
    if load_container_config "$container_name"; then
        echo
        print_status "INFO" "📊 Container Information: $container_name"
        echo "🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹"
        echo "🌍 OS: $OS_TYPE"
        echo "🏷️  Name: $CONTAINER_NAME"
        echo "🚀 Status: $STATUS"
        echo "🌐 IPv4: ${IPV4_ADDRESS:-Not assigned}"
        echo "🌐 IPv6: ${IPV6_ADDRESS:-Not assigned}"
        echo "🧠 Memory: ${MEMORY}MB"
        echo "⚡ CPUs: $CPUS"
        echo "💾 Disk: ${DISK_SIZE_GB}GB"
        echo "🛡️  Privileged: $PRIVILEGED"
        echo "🐳 Nesting: $NESTING"
        echo "🌐 DNS: $DNS_SERVERS"
        echo "💿 Storage Pool: $STORAGE_POOL"
        echo "📅 Created: $CREATED"
        echo "🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹"
        
        # Show more detailed info if running
        if [[ "$STATUS" == "RUNNING" ]]; then
            echo ""
            print_status "INFO" "📈 Container Status:"
            lxc info "$container_name" | grep -E "(Status:|IP addresses:|CPU usage:|Memory usage:|Disk usage:)" | head -10
        fi
        
        echo
        read -p "$(print_status "INPUT" "⏎ Press Enter to continue...")"
    fi
}

# Function to edit container configuration
edit_container_config() {
    local container_name=$1
    
    if load_container_config "$container_name"; then
        print_status "INFO" "✏️  Editing container: $container_name"
        
        while true; do
            echo "📝 What would you like to edit?"
            echo "  1) 💾 Disk Size"
            echo "  2) 🧠 Memory (RAM)"
            echo "  3) ⚡ CPU Count"
            echo "  4) 🌐 IPv4 Address"
            echo "  5) 🌐 IPv6 Address"
            echo "  6) 🛡️  Privileged Mode"
            echo "  7) 🐳 Nesting Mode"
            echo "  8) 🌐 DNS Servers"
            echo "  9) 🔧 Fix Network/DNS"
            echo "  0) ↩️  Back to main menu"
            
            read -p "$(print_status "INPUT" "🎯 Enter your choice: ")" edit_choice
            
            case $edit_choice in
                1)
                    while true; do
                        read -p "$(print_status "INPUT" "💾 Enter new disk size in GB (current: $DISK_SIZE_GB): ")" new_disk_size
                        new_disk_size="${new_disk_size:-$DISK_SIZE_GB}"
                        if validate_input "size_gb" "$new_disk_size"; then
                            if [[ "$new_disk_size" != "$DISK_SIZE_GB" ]]; then
                                lxc config device set "$container_name" root size="${new_disk_size}GB"
                                DISK_SIZE_GB="$new_disk_size"
                                DISK_SIZE_MB=$((new_disk_size * 1024))
                                print_status "SUCCESS" "✅ Disk size updated to ${new_disk_size}GB"
                            fi
                            break
                        fi
                    done
                    ;;
                2)
                    while true; do
                        read -p "$(print_status "INPUT" "🧠 Enter new memory in MB (current: $MEMORY): ")" new_memory
                        new_memory="${new_memory:-$MEMORY}"
                        if validate_input "size_mb" "$new_memory"; then
                            if [[ "$new_memory" != "$MEMORY" ]]; then
                                lxc config set "$container_name" limits.memory "${new_memory}MB"
                                MEMORY="$new_memory"
                                print_status "SUCCESS" "✅ Memory updated to ${new_memory}MB"
                            fi
                            break
                        fi
                    done
                    ;;
                3)
                    while true; do
                        read -p "$(print_status "INPUT" "⚡ Enter new CPU count (current: $CPUS): ")" new_cpus
                        new_cpus="${new_cpus:-$CPUS}"
                        if validate_input "number" "$new_cpus"; then
                            if [[ "$new_cpus" != "$CPUS" ]]; then
                                lxc config set "$container_name" limits.cpu "$new_cpus"
                                CPUS="$new_cpus"
                                print_status "SUCCESS" "✅ CPU count updated to $new_cpus"
                            fi
                            break
                        fi
                    done
                    ;;
                4)
                    while true; do
                        read -p "$(print_status "INPUT" "🌐 Enter new IPv4 address (current: ${IPV4_ADDRESS:-dhcp}): ")" new_ipv4
                        new_ipv4="${new_ipv4:-$IPV4_ADDRESS}"
                        if validate_input "ipv4" "$new_ipv4"; then
                            if [[ "$new_ipv4" == "none" ]]; then
                                lxc config device remove "$container_name" eth0 ipv4.address 2>/dev/null || true
                                IPV4_ADDRESS=""
                            elif [[ "$new_ipv4" == "dhcp" ]]; then
                                lxc config device remove "$container_name" eth0 ipv4.address 2>/dev/null || true
                                IPV4_ADDRESS="dhcp"
                            else
                                lxc config device set "$container_name" eth0 ipv4.address="$new_ipv4"
                                IPV4_ADDRESS="$new_ipv4"
                            fi
                            print_status "SUCCESS" "✅ IPv4 address updated"
                            break
                        fi
                    done
                    ;;
                5)
                    while true; do
                        read -p "$(print_status "INPUT" "🌐 Enter new IPv6 address (current: ${IPV6_ADDRESS:-auto}): ")" new_ipv6
                        new_ipv6="${new_ipv6:-$IPV6_ADDRESS}"
                        if validate_input "ipv6" "$new_ipv6"; then
                            if [[ "$new_ipv6" == "none" ]]; then
                                lxc config device remove "$container_name" eth0 ipv6.address 2>/dev/null || true
                                IPV6_ADDRESS=""
                            elif [[ "$new_ipv6" == "auto" ]]; then
                                lxc config device remove "$container_name" eth0 ipv6.address 2>/dev/null || true
                                IPV6_ADDRESS="auto"
                            else
                                lxc config device set "$container_name" eth0 ipv6.address="$new_ipv6"
                                IPV6_ADDRESS="$new_ipv6"
                            fi
                            print_status "SUCCESS" "✅ IPv6 address updated"
                            break
                        fi
                    done
                    ;;
                6)
                    while true; do
                        read -p "$(print_status "INPUT" "🛡️  Enable privileged mode? (y/n, current: $PRIVILEGED): ")" priv_input
                        if [[ "$priv_input" =~ ^[Yy]$ ]]; then 
                            lxc config set "$container_name" security.privileged "true"
                            PRIVILEGED="true"
                            print_status "SUCCESS" "✅ Privileged mode enabled"
                            break
                        elif [[ "$priv_input" =~ ^[Nn]$ ]]; then
                            lxc config set "$container_name" security.privileged "false"
                            PRIVILEGED="false"
                            print_status "SUCCESS" "✅ Privileged mode disabled"
                            break
                        elif [ -z "$priv_input" ]; then
                            break
                        else
                            print_status "ERROR" "❌ Please answer y or n"
                        fi
                    done
                    ;;
                7)
                    while true; do
                        read -p "$(print_status "INPUT" "🐳 Enable nesting mode? (y/n, current: $NESTING): ")" nest_input
                        if [[ "$nest_input" =~ ^[Yy]$ ]]; then 
                            lxc config set "$container_name" security.nesting "true"
                            NESTING="true"
                            print_status "SUCCESS" "✅ Nesting mode enabled"
                            break
                        elif [[ "$nest_input" =~ ^[Nn]$ ]]; then
                            lxc config set "$container_name" security.nesting "false"
                            NESTING="false"
                            print_status "SUCCESS" "✅ Nesting mode disabled"
                            break
                        elif [ -z "$nest_input" ]; then
                            break
                        else
                            print_status "ERROR" "❌ Please answer y or n"
                        fi
                    done
                    ;;
                8)
                    read -p "$(print_status "INPUT" "🌐 Enter new DNS servers (comma separated, current: $DNS_SERVERS): ")" new_dns
                    new_dns="${new_dns:-$DNS_SERVERS}"
                    lxc config device set "$container_name" eth0 dns.servers="$new_dns"
                    DNS_SERVERS="$new_dns"
                    print_status "SUCCESS" "✅ DNS servers updated"
                    ;;
                9)
                    print_status "INFO" "🔧 Fixing network/DNS issues..."
                    lxc exec "$container_name" -- bash -c "
                        echo 'nameserver 8.8.8.8' > /etc/resolv.conf
                        echo 'nameserver 8.8.4.4' >> /etc/resolv.conf
                        echo 'nameserver 1.1.1.1' >> /etc/resolv.conf
                        systemctl restart systemd-resolved 2>/dev/null || true
                    " 2>/dev/null
                    print_status "SUCCESS" "✅ Network/DNS issues fixed"
                    ;;
                0)
                    return 0
                    ;;
                *)
                    print_status "ERROR" "❌ Invalid selection"
                    continue
                    ;;
            esac
            
            # Save configuration
            save_container_config "$container_name"
            
            # Restart container if needed
            if [[ "$edit_choice" -ge 1 ]] && [[ "$edit_choice" -le 8 ]]; then
                read -p "$(print_status "INPUT" "🔄 Restart container to apply changes? (y/N): ")" restart_choice
                if [[ "$restart_choice" =~ ^[Yy]$ ]]; then
                    lxc restart "$container_name"
                    print_status "SUCCESS" "✅ Container restarted"
                fi
            fi
            
            read -p "$(print_status "INPUT" "🔄 Continue editing? (y/N): ")" continue_editing
            if [[ ! "$continue_editing" =~ ^[Yy]$ ]]; then
                break
            fi
        done
    fi
}

# Rest of the functions remain the same (stop_container, delete_container, show_container_info, etc.)
# ... [All other functions remain exactly the same as in previous script]

# Main menu function
main_menu() {
    while true; do
        display_header
        
        local containers=($(get_container_list))
        local container_count=${#containers[@]}
        
        if [ $container_count -gt 0 ]; then
            print_status "INFO" "📁 Found $container_count existing container(s):"
            for i in "${!containers[@]}"; do
                local status="💤"
                if lxc list "${containers[$i]}" --format csv 2>/dev/null | grep -q "RUNNING"; then
                    status="🚀"
                fi
                printf "  %2d) %s %s\n" $((i+1)) "${containers[$i]}" "$status"
            done
            echo
        fi
        
        echo "📋 Main Menu:"
        echo "  1) 🆕 Create a new container"
        if [ $container_count -gt 0 ]; then
            echo "  2) 🚀 Start a container"
            echo "  3) 🛑 Stop a container"
            echo "  4) 🔄 Restart a container"
            echo "  5) 📊 Show container info"
            echo "  6) ✏️  Edit container configuration"
            echo "  7) 🗑️  Delete a container"
            echo "  8) 📈 Resize container disk"
            echo "  9) 📊 Show container performance"
            echo "  10) 🔧 Fix container issues"
            echo "  11) 💻 Enter container shell"
            echo "  12) 📦 Clone container"
            echo "  13) 💾 Backup container"
            echo "  14) 📥 Restore container"
            echo "  15) 🌐 Show LXC system info"
            echo "  16) ⚙️  Fix all containers DNS"
        fi
        echo "  17) 🛠️  Fix LXC Storage Issues"
        echo "  0) 👋 Exit"
        echo
        
        read -p "$(print_status "INPUT" "🎯 Enter your choice: ")" choice
        
        case $choice in
            1)
                create_new_container
                ;;
            2)
                if [ $container_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "🚀 Enter container number to start: ")" container_num
                    if [[ "$container_num" =~ ^[0-9]+$ ]] && [ "$container_num" -ge 1 ] && [ "$container_num" -le $container_count ]; then
                        start_container "${containers[$((container_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            3)
                if [ $container_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "🛑 Enter container number to stop: ")" container_num
                    if [[ "$container_num" =~ ^[0-9]+$ ]] && [ "$container_num" -ge 1 ] && [ "$container_num" -le $container_count ]; then
                        stop_container "${containers[$((container_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            4)
                if [ $container_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "🔄 Enter container number to restart: ")" container_num
                    if [[ "$container_num" =~ ^[0-9]+$ ]] && [ "$container_num" -ge 1 ] && [ "$container_num" -le $container_count ]; then
                        stop_container "${containers[$((container_num-1))]}"
                        sleep 2
                        start_container "${containers[$((container_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            5)
                if [ $container_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "📊 Enter container number to show info: ")" container_num
                    if [[ "$container_num" =~ ^[0-9]+$ ]] && [ "$container_num" -ge 1 ] && [ "$container_num" -le $container_count ]; then
                        show_container_info "${containers[$((container_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            6)
                if [ $container_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "✏️  Enter container number to edit: ")" container_num
                    if [[ "$container_num" =~ ^[0-9]+$ ]] && [ "$container_num" -ge 1 ] && [ "$container_num" -le $container_count ]; then
                        edit_container_config "${containers[$((container_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            7)
                if [ $container_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "🗑️  Enter container number to delete: ")" container_num
                    if [[ "$container_num" =~ ^[0-9]+$ ]] && [ "$container_num" -ge 1 ] && [ "$container_num" -le $container_count ]; then
                        delete_container "${containers[$((container_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            8)
                if [ $container_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "📈 Enter container number to resize disk: ")" container_num
                    if [[ "$container_num" =~ ^[0-9]+$ ]] && [ "$container_num" -ge 1 ] && [ "$container_num" -le $container_count ]; then
                        resize_container_disk "${containers[$((container_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            9)
                if [ $container_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "📊 Enter container number to show performance: ")" container_num
                    if [[ "$container_num" =~ ^[0-9]+$ ]] && [ "$container_num" -ge 1 ] && [ "$container_num" -le $container_count ]; then
                        show_container_performance "${containers[$((container_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            10)
                if [ $container_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "🔧 Enter container number to fix issues: ")" container_num
                    if [[ "$container_num" =~ ^[0-9]+$ ]] && [ "$container_num" -ge 1 ] && [ "$container_num" -le $container_count ]; then
                        fix_container_issues "${containers[$((container_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            11)
                if [ $container_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "💻 Enter container number to access shell: ")" container_num
                    if [[ "$container_num" =~ ^[0-9]+$ ]] && [ "$container_num" -ge 1 ] && [ "$container_num" -le $container_count ]; then
                        enter_container_shell "${containers[$((container_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            12)
                if [ $container_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "📦 Enter container number to clone: ")" container_num
                    if [[ "$container_num" =~ ^[0-9]+$ ]] && [ "$container_num" -ge 1 ] && [ "$container_num" -le $container_count ]; then
                        clone_container "${containers[$((container_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            13)
                if [ $container_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "💾 Enter container number to backup: ")" container_num
                    if [[ "$container_num" =~ ^[0-9]+$ ]] && [ "$container_num" -ge 1 ] && [ "$container_num" -le $container_count ]; then
                        backup_container "${containers[$((container_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            14)
                restore_container
                ;;
            15)
                show_lxc_info
                ;;
            16)
                print_status "INFO" "🔧 Fixing DNS in all containers..."
                for container in "${containers[@]}"; do
                    if lxc list "$container" --format csv 2>/dev/null | grep -q "RUNNING"; then
                        print_status "INFO" "  Fixing DNS in $container..."
                        lxc exec "$container" -- bash -c "
                            echo 'nameserver 8.8.8.8' > /etc/resolv.conf
                            echo 'nameserver 8.8.4.4' >> /etc/resolv.conf
                            echo 'nameserver 1.1.1.1' >> /etc/resolv.conf
                        " 2>/dev/null
                    fi
                done
                print_status "SUCCESS" "✅ DNS fixed in all running containers"
                ;;
            17)
                print_status "INFO" "🛠️  Fixing LXC storage issues..."
                
                # Check if default storage exists
                if ! lxc storage list --format csv 2>/dev/null | grep -q "default"; then
                    print_status "INFO" "💾 Creating default storage pool..."
                    lxc storage create default dir
                fi
                
                # Check default profile
                if ! lxc profile show default 2>/dev/null | grep -q "root:"; then
                    print_status "INFO" "⚙️  Configuring default profile..."
                    lxc profile device add default root disk path=/ pool=default
                fi
                
                # Initialize LXD if not done
                if ! lxc project list &>/dev/null; then
                    print_status "INFO" "🚀 Initializing LXD..."
                    sudo lxd init --auto
                fi
                
                print_status "SUCCESS" "✅ LXC storage issues fixed"
                ;;
            0)
                print_status "INFO" "👋 Goodbye!"
                exit 0
                ;;
            *)
                print_status "ERROR" "❌ Invalid option"
                ;;
        esac
        
        read -p "$(print_status "INPUT" "⏎ Press Enter to continue...")"
    done
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Check dependencies
check_dependencies

# Initialize paths
CONFIG_DIR="$HOME/.lxc_manager"
mkdir -p "$CONFIG_DIR"

# Color definitions for echo
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Supported OS list for LXC - UPDATED WITH CORRECT IMAGE NAMES
declare -A OS_OPTIONS=(
    ["Ubuntu 22.04 LTS"]="ubuntu|ubuntu:22.04|ubuntu22"
    ["Ubuntu 24.04 LTS"]="ubuntu|ubuntu:24.04|ubuntu24"
    ["Debian 11 Bullseye"]="debian|debian:11|debian11"
    ["Debian 12 Bookworm"]="debian|debian:12|debian12"
    ["Debian 13 Trixie"]="debian|debian:13|debian13"
    ["CentOS 7"]="centos|centos:7|centos7"
    ["AlmaLinux 9"]="almalinux|almalinux:9|almalinux9"
    ["Rocky Linux 9"]="rockylinux|rockylinux:9|rocky9"
    ["Alpine Linux Edge"]="alpine|alpine/edge|alpine"
    ["Arch Linux"]="archlinux|archlinux|arch"
)

# Check LXD initialization
if ! lxc project list &>/dev/null; then
    print_status "WARN" "⚠️  LXD not initialized. Initializing now..."
    sudo lxd init --auto
    sudo usermod -aG lxd $USER
    print_status "SUCCESS" "✅ LXD initialized! Please logout and login again or run: newgrp lxd"
    exit 0
fi

# Check if user is in lxd group
if ! groups $USER | grep -q lxd; then
    print_status "WARN" "⚠️  User not in lxd group. Adding..."
    sudo usermod -aG lxd $USER
    print_status "SUCCESS" "✅ User added to lxd group! Please run: newgrp lxd"
    print_status "INFO" "📝 Then run this script again."
    exit 0
fi

# Start the main menu
main_menu
