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
        "size")
            if ! [[ "$value" =~ ^[0-9]+[GgMm]$ ]]; then
                print_status "ERROR" "❌ Must be a size with unit (e.g., 100G, 512M)"
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
        "username")
            if ! [[ "$value" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
                print_status "ERROR" "❌ Username must start with a letter or underscore, and contain only letters, numbers, hyphens, and underscores"
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
    unset CONTAINER_NAME OS_TYPE DISK_SIZE MEMORY CPUS IPV4_ADDRESS IPV6_ADDRESS
    unset SSH_PORT STATUS CREATED NETWORK_TYPE PRIVILEGED NESTING DNS_SERVERS
    
    # Get container info
    if lxc info "$container_name" &>/dev/null; then
        CONTAINER_NAME="$container_name"
        OS_TYPE=$(lxc config get "$container_name" image.description 2>/dev/null || echo "Unknown")
        DISK_SIZE=$(lxc config get "$container_name" root.size 2>/dev/null || echo "10GB")
        MEMORY=$(lxc config get "$container_name" limits.memory 2>/dev/null || echo "1GB")
        CPUS=$(lxc config get "$container_name" limits.cpu 2>/dev/null || echo "1")
        IPV4_ADDRESS=$(lxc list "$container_name" --format csv 2>/dev/null | cut -d',' -f4 | xargs)
        IPV6_ADDRESS=$(lxc list "$container_name" --format csv 2>/dev/null | cut -d',' -f5 | xargs)
        STATUS=$(lxc list "$container_name" --format csv 2>/dev/null | cut -d',' -f2 | xargs)
        CREATED=$(lxc info "$container_name" | grep "Created:" | cut -d: -f2- | xargs)
        NETWORK_TYPE=$(lxc config get "$container_name" network 2>/dev/null || echo "bridge")
        PRIVILEGED=$(lxc config get "$container_name" security.privileged 2>/dev/null || echo "false")
        NESTING=$(lxc config get "$container_name" security.nesting 2>/dev/null || echo "false")
        DNS_SERVERS=$(lxc config device get "$container_name" eth0 dns.servers 2>/dev/null || echo "8.8.8.8,8.8.4.4")
        
        return 0
    else
        print_status "ERROR" "📦 Container '$container_name' not found"
        return 1
    fi
}

# Function to save container configuration
save_container_config() {
    local container_name=$1
    local config_file="$CONFIG_DIR/$container_name.conf"
    
    cat > "$config_file" <<EOF
CONTAINER_NAME="$CONTAINER_NAME"
OS_TYPE="$OS_TYPE"
DISK_SIZE="$DISK_SIZE"
MEMORY="$MEMORY"
CPUS="$CPUS"
IPV4_ADDRESS="$IPV4_ADDRESS"
IPV6_ADDRESS="$IPV6_ADDRESS"
STATUS="$STATUS"
CREATED="$CREATED"
NETWORK_TYPE="$NETWORK_TYPE"
PRIVILEGED="$PRIVILEGED"
NESTING="$NESTING"
DNS_SERVERS="$DNS_SERVERS"
EOF
    
    print_status "SUCCESS" "💾 Configuration saved to $config_file"
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

    # Resource Configuration
    while true; do
        read -p "$(print_status "INPUT" "💾 Disk size (default: 10G): ")" DISK_SIZE
        DISK_SIZE="${DISK_SIZE:-10G}"
        if validate_input "size" "$DISK_SIZE"; then
            break
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "🧠 Memory in MB (default: 1024): ")" MEMORY
        MEMORY="${MEMORY:-1024}"
        if validate_input "number" "$MEMORY"; then
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

    # Create and setup container
    setup_container
    
    # Save configuration
    save_container_config "$CONTAINER_NAME"
}

# Function to setup container
setup_container() {
    print_status "INFO" "📥 Creating container '$CONTAINER_NAME'..."
    
    # Create container
    if ! lxc launch "$IMAGE_NAME" "$CONTAINER_NAME"; then
        print_status "ERROR" "❌ Failed to launch container. Checking LXD configuration..."
        
        # Fix common LXD issues
        if ! lxc storage list | grep -q default; then
            print_status "INFO" "💾 Creating default storage..."
            lxc storage create default dir
        fi
        
        if ! lxc profile show default | grep -q "root:"; then
            print_status "INFO" "⚙️  Configuring default profile..."
            lxc profile device add default root disk path=/ pool=default
        fi
        
        # Try again
        if ! lxc launch "$IMAGE_NAME" "$CONTAINER_NAME"; then
            print_status "ERROR" "❌ Still failed. Please check LXD installation."
            exit 1
        fi
    fi
    
    # Configure resources
    print_status "INFO" "⚙️  Configuring resources..."
    lxc config set "$CONTAINER_NAME" limits.cpu "$CPUS"
    lxc config set "$CONTAINER_NAME" limits.memory "${MEMORY}MB"
    lxc config device override "$CONTAINER_NAME" root size="$DISK_SIZE"
    
    # Configure networking
    if [[ "$IPV4_ADDRESS" != "dhcp" ]] && [[ "$IPV4_ADDRESS" != "none" ]] && [[ -n "$IPV4_ADDRESS" ]]; then
        lxc config device set "$CONTAINER_NAME" eth0 ipv4.address="$IPV4_ADDRESS"
    fi
    
    if [[ "$IPV6_ADDRESS" != "auto" ]] && [[ "$IPV6_ADDRESS" != "none" ]] && [[ -n "$IPV6_ADDRESS" ]]; then
        lxc config device set "$CONTAINER_NAME" eth0 ipv6.address="$IPV6_ADDRESS"
    fi
    
    # Configure advanced options
    lxc config set "$CONTAINER_NAME" security.privileged "$PRIVILEGED"
    lxc config set "$CONTAINER_NAME" security.nesting "$NESTING"
    
    # Configure DNS
    lxc config device set "$CONTAINER_NAME" eth0 dns.servers="$DNS_SERVERS"
    
    # Fix DNS inside container
    print_status "INFO" "🔧 Fixing DNS inside container..."
    lxc exec "$CONTAINER_NAME" -- bash -c "
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
        fi
    " 2>/dev/null || true
    
    print_status "SUCCESS" "🎉 Container '$CONTAINER_NAME' created successfully!"
    
    # Show connection info
    print_status "INFO" "🔌 Connection Information:"
    echo "  Shell: ${YELLOW}lxc exec $CONTAINER_NAME -- bash${NC}"
    echo "  Console: ${YELLOW}lxc console $CONTAINER_NAME${NC}"
    
    # Get IP addresses
    sleep 2
    IPV4_ADDRESS=$(lxc list "$CONTAINER_NAME" --format csv 2>/dev/null | cut -d',' -f4 | xargs)
    IPV6_ADDRESS=$(lxc list "$CONTAINER_NAME" --format csv 2>/dev/null | cut -d',' -f5 | xargs)
    
    if [[ -n "$IPV4_ADDRESS" ]]; then
        echo "  🌐 IPv4: ${GREEN}$IPV4_ADDRESS${NC}"
        echo "  🔗 SSH: ${YELLOW}ssh ubuntu@$IPV4_ADDRESS${NC}"
    fi
    
    if [[ -n "$IPV6_ADDRESS" ]]; then
        echo "  🌐 IPv6: ${GREEN}$IPV6_ADDRESS${NC}"
    fi
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
            return 1
        fi
        
        # Update status
        STATUS="RUNNING"
        save_container_config "$container_name"
        
        print_status "SUCCESS" "✅ Container '$container_name' started"
        
        # Show connection info
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
        echo "🧠 Memory: $MEMORY"
        echo "⚡ CPUs: $CPUS"
        echo "💾 Disk: $DISK_SIZE"
        echo "🛡️  Privileged: $PRIVILEGED"
        echo "🐳 Nesting: $NESTING"
        echo "🌐 DNS: $DNS_SERVERS"
        echo "📅 Created: $CREATED"
        echo "🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹"
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
                        read -p "$(print_status "INPUT" "💾 Enter new disk size (current: $DISK_SIZE): ")" new_disk_size
                        new_disk_size="${new_disk_size:-$DISK_SIZE}"
                        if validate_input "size" "$new_disk_size"; then
                            if [[ "$new_disk_size" != "$DISK_SIZE" ]]; then
                                lxc config device override "$container_name" root size="$new_disk_size"
                                DISK_SIZE="$new_disk_size"
                                print_status "SUCCESS" "✅ Disk size updated to $new_disk_size"
                            fi
                            break
                        fi
                    done
                    ;;
                2)
                    while true; do
                        read -p "$(print_status "INPUT" "🧠 Enter new memory in MB (current: $MEMORY): ")" new_memory
                        new_memory="${new_memory:-$MEMORY}"
                        if validate_input "number" "$new_memory"; then
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
            
            read -p "$(print_status "INPUT" "🔄 Continue editing? (y/N): ")" continue_editing
            if [[ ! "$continue_editing" =~ ^[Yy]$ ]]; then
                break
            fi
        done
    fi
}

# Function to resize container disk
resize_container_disk() {
    local container_name=$1
    
    if load_container_config "$container_name"; then
        # Check if container is running
        if [[ "$STATUS" == "RUNNING" ]]; then
            print_status "ERROR" "❌ Cannot resize disk while container is running. Please stop the container first."
            return 1
        fi
        
        print_status "INFO" "💾 Current disk size: $DISK_SIZE"
        
        while true; do
            read -p "$(print_status "INPUT" "📈 Enter new disk size (e.g., 50G): ")" new_disk_size
            if validate_input "size" "$new_disk_size"; then
                if [[ "$new_disk_size" == "$DISK_SIZE" ]]; then
                    print_status "INFO" "ℹ️  New disk size is the same as current size. No changes made."
                    return 0
                fi
                
                print_status "INFO" "📈 Resizing disk to $new_disk_size..."
                if lxc config device override "$container_name" root size="$new_disk_size"; then
                    DISK_SIZE="$new_disk_size"
                    save_container_config "$container_name"
                    print_status "SUCCESS" "✅ Disk resized successfully to $new_disk_size"
                else
                    print_status "ERROR" "❌ Failed to resize disk"
                    return 1
                fi
                break
            fi
        done
    fi
}

# Function to show container performance
show_container_performance() {
    local container_name=$1
    
    if load_container_config "$container_name"; then
        print_status "INFO" "📊 Performance metrics for container: $container_name"
        echo "📈📈📈📈📈📈📈📈📈📈📈📈📈📈📈"
        
        if [[ "$STATUS" == "RUNNING" ]]; then
            # Show container stats
            echo "⚡ Container Stats:"
            lxc exec "$container_name" -- bash -c "
                echo 'CPU Usage:'
                top -bn1 | grep 'Cpu(s)'
                echo ''
                echo 'Memory Usage:'
                free -h
                echo ''
                echo 'Disk Usage:'
                df -h /
                echo ''
                echo 'Uptime:'
                uptime
            " 2>/dev/null || echo "Cannot get stats (container may be down)"
        else
            print_status "INFO" "💤 Container $container_name is not running"
            echo "⚙️  Configuration:"
            echo "  🧠 Memory: $MEMORY"
            echo "  ⚡ CPUs: $CPUS"
            echo "  💾 Disk: $DISK_SIZE"
        fi
        echo "📈📈📈📈📈📈📈📈📈📈📈📈📈📈📈"
        read -p "$(print_status "INPUT" "⏎ Press Enter to continue...")"
    fi
}

# Function to fix container issues
fix_container_issues() {
    local container_name=$1
    
    if load_container_config "$container_name"; then
        print_status "INFO" "🔧 Fixing issues for container: $container_name"
        
        echo "🔧 Select issue to fix:"
        echo "  1) 🔄 Restart container"
        echo "  2) 🌐 Fix network/DNS"
        echo "  3) 🔧 Reconfigure container"
        echo "  4) 💀 Kill stuck processes"
        echo "  0) ↩️  Back"
        
        read -p "$(print_status "INPUT" "🎯 Enter your choice: ")" fix_choice
        
        case $fix_choice in
            1)
                print_status "INFO" "🔄 Restarting container..."
                lxc restart "$container_name"
                print_status "SUCCESS" "✅ Container restarted"
                ;;
            2)
                print_status "INFO" "🌐 Fixing network/DNS..."
                lxc exec "$container_name" -- bash -c "
                    echo 'nameserver 8.8.8.8' > /etc/resolv.conf
                    echo 'nameserver 8.8.4.4' >> /etc/resolv.conf
                    echo 'nameserver 1.1.1.1' >> /etc/resolv.conf
                    systemctl restart systemd-resolved 2>/dev/null || true
                    systemctl restart networking 2>/dev/null || true
                    echo 'Network fixed!'
                " 2>/dev/null
                print_status "SUCCESS" "✅ Network/DNS fixed"
                ;;
            3)
                print_status "INFO" "🔧 Reconfiguring container..."
                # Reapply configuration
                lxc config set "$container_name" limits.cpu "$CPUS"
                lxc config set "$container_name" limits.memory "${MEMORY}MB"
                lxc config device override "$container_name" root size="$DISK_SIZE"
                lxc config set "$container_name" security.privileged "$PRIVILEGED"
                lxc config set "$container_name" security.nesting "$NESTING"
                print_status "SUCCESS" "✅ Container reconfigured"
                ;;
            4)
                print_status "INFO" "💀 Killing stuck processes..."
                lxc exec "$container_name" -- bash -c "
                    pkill -9 -f 'apt-get\|dpkg\|apt' 2>/dev/null || true
                    echo 'Stuck processes cleaned'
                " 2>/dev/null
                print_status "SUCCESS" "✅ Stuck processes cleaned"
                ;;
            0)
                return 0
                ;;
            *)
                print_status "ERROR" "❌ Invalid selection"
                ;;
        esac
    fi
}

# Function to enter container shell
enter_container_shell() {
    local container_name=$1
    
    if load_container_config "$container_name"; then
        if [[ "$STATUS" != "RUNNING" ]]; then
            print_status "ERROR" "❌ Container '$container_name' is not running"
            read -p "$(print_status "INPUT" "🚀 Start container now? (y/N): ")" start_now
            if [[ "$start_now" =~ ^[Yy]$ ]]; then
                start_container "$container_name"
                sleep 2
            else
                return 1
            fi
        fi
        
        print_status "INFO" "💻 Entering container shell..."
        echo "🚪 Type 'exit' to return to menu"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        lxc exec "$container_name" -- /bin/bash
    fi
}

# Function to clone container
clone_container() {
    local container_name=$1
    
    if load_container_config "$container_name"; then
        print_status "INFO" "📋 Cloning container: $container_name"
        
        read -p "$(print_status "INPUT" "🏷️  Enter name for new container: ")" new_name
        
        if ! validate_input "name" "$new_name"; then
            return 1
        fi
        
        # Check if new container already exists
        if lxc list --format csv 2>/dev/null | grep -q "^$new_name,"; then
            print_status "ERROR" "❌ Container '$new_name' already exists"
            return 1
        fi
        
        print_status "INFO" "📦 Cloning $container_name to $new_name..."
        if lxc copy "$container_name" "$new_name"; then
            print_status "SUCCESS" "✅ Container cloned successfully"
            
            # Start cloned container
            read -p "$(print_status "INPUT" "🚀 Start cloned container? (y/N): ")" start_clone
            if [[ "$start_clone" =~ ^[Yy]$ ]]; then
                lxc start "$new_name"
                print_status "SUCCESS" "✅ Cloned container started"
            fi
        else
            print_status "ERROR" "❌ Failed to clone container"
        fi
    fi
}

# Function to backup container
backup_container() {
    local container_name=$1
    
    if load_container_config "$container_name"; then
        print_status "INFO" "💾 Creating backup of container: $container_name"
        
        local backup_dir="$HOME/lxc_backups"
        mkdir -p "$backup_dir"
        local backup_file="$backup_dir/${container_name}_$(date +%Y%m%d_%H%M%S).tar.gz"
        
        print_status "INFO" "📦 Exporting container..."
        if lxc export "$container_name" "$backup_file"; then
            local file_size=$(du -h "$backup_file" | cut -f1)
            print_status "SUCCESS" "✅ Backup created: $backup_file ($file_size)"
        else
            print_status "ERROR" "❌ Failed to backup container"
        fi
    fi
}

# Function to restore container
restore_container() {
    print_status "INFO" "📥 Restoring container from backup"
    
    local backup_dir="$HOME/lxc_backups"
    if [[ ! -d "$backup_dir" ]]; then
        print_status "ERROR" "❌ Backup directory not found: $backup_dir"
        return 1
    fi
    
    # List backups
    local backups=($(ls "$backup_dir"/*.tar.gz 2>/dev/null))
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        print_status "ERROR" "❌ No backup files found"
        return 1
    fi
    
    echo "📁 Available backups:"
    for i in "${!backups[@]}"; do
        local file_name=$(basename "${backups[$i]}")
        local file_size=$(du -h "${backups[$i]}" | cut -f1)
        printf "  %2d) %s (%s)\n" $((i+1)) "$file_name" "$file_size"
    done
    
    read -p "$(print_status "INPUT" "🎯 Select backup to restore: ")" backup_choice
    
    if [[ "$backup_choice" =~ ^[0-9]+$ ]] && [ "$backup_choice" -ge 1 ] && [ "$backup_choice" -le ${#backups[@]} ]; then
        local backup_file="${backups[$((backup_choice-1))]}"
        
        read -p "$(print_status "INPUT" "🏷️  Enter name for restored container: ")" restore_name
        
        if ! validate_input "name" "$restore_name"; then
            return 1
        fi
        
        # Check if container already exists
        if lxc list --format csv 2>/dev/null | grep -q "^$restore_name,"; then
            print_status "ERROR" "❌ Container '$restore_name' already exists"
            return 1
        fi
        
        print_status "INFO" "📥 Restoring from $backup_file..."
        if lxc import "$backup_file" "$restore_name"; then
            print_status "SUCCESS" "✅ Container restored successfully"
            
            # Start restored container
            read -p "$(print_status "INPUT" "🚀 Start restored container? (y/N): ")" start_restore
            if [[ "$start_restore" =~ ^[Yy]$ ]]; then
                lxc start "$restore_name"
                print_status "SUCCESS" "✅ Restored container started"
            fi
        else
            print_status "ERROR" "❌ Failed to restore container"
        fi
    else
        print_status "ERROR" "❌ Invalid selection"
    fi
}

# Function to show LXC system info
show_lxc_info() {
    print_status "INFO" "📊 LXC System Information"
    echo "🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹"
    
    echo "🌐 LXD Version:"
    lxd --version 2>/dev/null || echo "Not installed"
    
    echo ""
    echo "💾 Storage Pools:"
    lxc storage list --format table
    
    echo ""
    echo "🔌 Networks:"
    lxc network list --format table
    
    echo ""
    echo "📦 Container Summary:"
    local total=$(lxc list --format csv 2>/dev/null | wc -l)
    local running=$(lxc list status=RUNNING --format csv 2>/dev/null | wc -l)
    echo "  Total: $total"
    echo "  Running: $running"
    echo "  Stopped: $((total - running))"
    
    echo ""
    echo "⚡ System Resources:"
    free -h
    echo ""
    df -h /
    
    echo "🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹"
    read -p "$(print_status "INPUT" "⏎ Press Enter to continue...")"
}

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
        fi
        echo "  15) 🌐 Show LXC system info"
        echo "  16) ⚙️  Fix all containers DNS"
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

# Supported OS list for LXC
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
