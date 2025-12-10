#!/bin/bash
set -euo pipefail

# =============================
# Enhanced Multi-VM Manager with TUI
# =============================

# Configuration
CONFIG_FILE="$HOME/.vm-manager.conf"
VM_DIR="${VM_DIR:-$HOME/vms}"
LOG_FILE="$VM_DIR/vm-manager.log"

# Colors for UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Symbols
CHECK="✓"
CROSS="✗"
INFO="ℹ"
WARN="⚠"
ARROW="➜"
DISK="💾"
CPU="⚡"
RAM="🧠"
NET="🌐"
USER="👤"
KEY="🔑"
TERM="💻"
ROCKET="🚀"
STOP="🛑"
TRASH="🗑️"
GEAR="⚙️"
PLUS="➕"
SEARCH="🔍"
GRAPH="📊"
LOCK="🔒"
UNLOCK="🔓"
FIX="🔧"
EDIT="✏️"
BACK="↩️"

# Supported OS list - Comprehensive Linux Distributions
declare -A OS_OPTIONS=(
    # Ubuntu
    ["Ubuntu 20.04 LTS"]="ubuntu|focal|https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img|ubuntu20|ubuntu|ubuntu"
    ["Ubuntu 22.04 LTS"]="ubuntu|jammy|https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img|ubuntu22|ubuntu|ubuntu"
    ["Ubuntu 24.04 LTS"]="ubuntu|noble|https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img|ubuntu24|ubuntu|ubuntu"
    
    # Debian
    ["Debian 11 (Bullseye)"]="debian|bullseye|https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2|debian11|debian|debian"
    ["Debian 12 (Bookworm)"]="debian|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|debian12|debian|debian"
    ["Debian 13 (Trixie)"]="debian|trixie|https://cloud.debian.org/images/cloud/trixie/daily/latest/debian-13-generic-amd64-daily.qcow2|debian13|debian|debian"
    
    # Fedora
    ["Fedora 39"]="fedora|39|https://download.fedoraproject.org/pub/fedora/linux/releases/39/Cloud/x86_64/images/Fedora-Cloud-Base-39-1.5.x86_64.qcow2|fedora39|fedora|fedora"
    ["Fedora 40"]="fedora|40|https://download.fedoraproject.org/pub/fedoraproject.org/pub/fedora/linux/releases/40/Cloud/x86_64/images/Fedora-Cloud-Base-40-1.14.x86_64.qcow2|fedora40|fedora|fedora"
    
    # CentOS
    ["CentOS Stream 8"]="centos|stream8|https://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2|centos8|centos|centos"
    ["CentOS Stream 9"]="centos|stream9|https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2|centos9|centos|centos"
    
    # RHEL-based
    ["AlmaLinux 8"]="almalinux|8|https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2|almalinux8|alma|alma"
    ["AlmaLinux 9"]="almalinux|9|https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2|almalinux9|alma|alma"
    ["Rocky Linux 8"]="rockylinux|8|https://download.rockylinux.org/pub/rocky/8/images/x86_64/Rocky-8-GenericCloud.latest.x86_64.qcow2|rocky8|rocky|rocky"
    ["Rocky Linux 9"]="rockylinux|9|https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2|rocky9|rocky|rocky"
    
    # Arch & derivatives
    ["Arch Linux"]="arch|latest|https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2|archlinux|arch|arch"
    ["Manjaro Linux"]="manjaro|latest|https://download.manjaro.org/images/cloud/latest/manjaro-x86_64-cloudimg.qcow2|manjaro|manjaro|manjaro"
    
    # SUSE
    ["openSUSE Leap 15.5"]="opensuse|leap15.5|https://download.opensuse.org/distribution/leap/15.5/cloud/openSUSE-Leap-15.5.x86_64-NoCloud.qcow2|opensuse15|opensuse|opensuse"
    ["openSUSE Tumbleweed"]="opensuse|tumbleweed|https://download.opensuse.org/tumbleweed/appliances/openSUSE-Tumbleweed.x86_64-Cloud.qcow2|tumbleweed|opensuse|opensuse"
    
    # Lightweight
    ["Alpine Linux 3.19"]="alpine|3.19|https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-standard-3.19.0-x86_64.iso|alpine319|alpine|alpine"
    ["Alpine Linux 3.20"]="alpine|3.20|https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86_64/alpine-standard-3.20.0-x86_64.iso|alpine320|alpine|alpine"
    
    # Enterprise
    ["Oracle Linux 8"]="oraclelinux|8|https://yum.oracle.com/templates/OracleLinux/OL8/u8/x86_64/OL8U8_x86_64-kvm-b142.qcow|oracle8|oracle|oracle"
    ["Oracle Linux 9"]="oraclelinux|9|https://yum.oracle.com/templates/OracleLinux/OL9/u1/x86_64/OL9U1_x86_64-kvm-b211.qcow|oracle9|oracle|oracle"
    
    # Specialized
    ["Kali Linux 2024.2"]="kali|2024.2|https://cdimage.kali.org/kali-2024.2/kali-linux-2024.2-qemu-amd64.qcow2|kali2024|kali|kali"
    ["NixOS 23.11"]="nixos|23.11|https://channels.nixos.org/nixos-23.11/latest-nixos-plasma6-x86_64-linux.iso|nixos23|nixos|nixos"
    
    # Cloud-optimized
    ["Amazon Linux 2023"]="amazonlinux|2023|https://cdn.amazonlinux.com/al2023/current/community/x86_64/AL2023-KVM-2023.3.20240513.0-kernel-6.1-x86_64.xfs.gpt.qcow2|amazon2023|ec2-user|amazon"
    ["Clear Linux"]="clearlinux|latest|https://cdn.download.clearlinux.org/releases/current/clear/clear-latest-kvm.img|clearlinux|clear|clear"
)

# Logging function
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Print colored messages
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_header() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
 __   __  _______  __   __    _______  _______  _______  ______    _______ 
|  |_|  ||   _   ||  | |  |  |       ||       ||   _   ||    _ |  |       |
|       ||  |_|  ||  | |  |  |    ___||    ___||  |_|  ||   | ||  |  _____|
|       ||       ||  |_|  |  |   | __ |   |___ |       ||   |_||_ | |_____ 
|       ||       ||       |  |   ||  ||    ___||       ||    __  ||_____  |
| ||_|| ||   _   ||       |  |   |_| ||   |___ |   _   ||   |  | | _____| |
|_|   |_||__| |__||_______|  |_______||_______||__| |__||___|  |_||_______|
EOF
    echo -e "${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}            Virtual Machine Management System${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    echo
}

print_status() {
    local type=$1
    local message=$2
    
    case $type in
        "SUCCESS") echo -e "${GREEN}${CHECK} ${message}${NC}" ;;
        "ERROR") echo -e "${RED}${CROSS} ${message}${NC}" ;;
        "WARN") echo -e "${YELLOW}${WARN} ${message}${NC}" ;;
        "INFO") echo -e "${BLUE}${INFO} ${message}${NC}" ;;
        "INPUT") echo -e "${MAGENTA}${ARROW} ${message}${NC}" ;;
        "DEBUG") echo -e "${CYAN}${SEARCH} ${message}${NC}" ;;
    esac
    log_message "$type" "$message"
}

# Check dependencies
check_dependencies() {
    local deps=("qemu-system-x86_64" "wget" "cloud-localds" "qemu-img" "lsof" "dialog")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_status "ERROR" "Missing dependencies: ${missing_deps[*]}"
        echo
        print_status "INFO" "Install missing packages with:"
        echo "  Ubuntu/Debian: sudo apt install qemu-system cloud-image-utils wget lsof dialog"
        echo "  Fedora/RHEL:   sudo dnf install qemu-kvm cloud-utils wget lsof dialog"
        echo "  Arch:          sudo pacman -S qemu-full cloud-utils wget lsof dialog"
        exit 1
    fi
}

# Initialize directories
init_directories() {
    mkdir -p "$VM_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Create default config if not exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" <<EOF
# VM Manager Configuration
VM_DIR="$VM_DIR"
DEFAULT_MEMORY=2048
DEFAULT_CPUS=2
DEFAULT_DISK="20G"
DEFAULT_SSH_PORT=2222
AUTO_START=false
THEME="dark"
EOF
    fi
    
    # Load configuration
    source "$CONFIG_FILE" 2>/dev/null || true
}

# Get all VMs
get_vm_list() {
    find "$VM_DIR" -name "*.conf" -exec basename {} .conf \; 2>/dev/null | sort
}

# Get running VMs
get_running_vms() {
    local running_vms=()
    for vm in $(get_vm_list); do
        if is_vm_running "$vm"; then
            running_vms+=("$vm")
        fi
    done
    echo "${running_vms[@]}"
}

# Check if VM is running
is_vm_running() {
    local vm_name=$1
    if load_vm_config "$vm_name" 2>/dev/null; then
        if pgrep -f "qemu-system.*$IMG_FILE" >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# Load VM configuration
load_vm_config() {
    local vm_name=$1
    local config_file="$VM_DIR/$vm_name.conf"
    
    if [[ -f "$config_file" ]]; then
        # Clear previous variables
        unset VM_NAME OS_TYPE CODENAME IMG_URL HOSTNAME USERNAME PASSWORD
        unset DISK_SIZE MEMORY CPUS SSH_PORT GUI_MODE PORT_FORWARDS IMG_FILE SEED_FILE CREATED
        
        source "$config_file"
        return 0
    else
        print_status "ERROR" "Configuration for VM '$vm_name' not found"
        return 1
    fi
}

# Save VM configuration
save_vm_config() {
    local config_file="$VM_DIR/$VM_NAME.conf"
    
    cat > "$config_file" <<EOF
VM_NAME="$VM_NAME"
OS_TYPE="$OS_TYPE"
CODENAME="$CODENAME"
IMG_URL="$IMG_URL"
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
DISK_SIZE="$DISK_SIZE"
MEMORY="$MEMORY"
CPUS="$CPUS"
SSH_PORT="$SSH_PORT"
GUI_MODE="$GUI_MODE"
PORT_FORWARDS="$PORT_FORWARDS"
IMG_FILE="$IMG_FILE"
SEED_FILE="$SEED_FILE"
CREATED="$CREATED"
EOF
    
    print_status "SUCCESS" "Configuration saved to $config_file"
}

# Create cloud-init config
create_cloud_init() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        # Create user-data
        cat > "$VM_DIR/user-data" <<EOF
#cloud-config
hostname: $HOSTNAME
ssh_pwauth: true
disable_root: false
users:
  - name: $USERNAME
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    password: $(openssl passwd -6 "$PASSWORD" | tr -d '\n')
chpasswd:
  list: |
    root:$PASSWORD
    $USERNAME:$PASSWORD
  expire: false
EOF

        # Create meta-data
        cat > "$VM_DIR/meta-data" <<EOF
instance-id: iid-$VM_NAME
local-hostname: $HOSTNAME
EOF

        # Create seed image
        if cloud-localds "$SEED_FILE" "$VM_DIR/user-data" "$VM_DIR/meta-data" 2>/dev/null; then
            print_status "SUCCESS" "Cloud-init configuration created"
        else
            print_status "ERROR" "Failed to create cloud-init seed image"
            return 1
        fi
        
        # Cleanup
        rm -f "$VM_DIR/user-data" "$VM_DIR/meta-data"
    fi
}

# Setup VM image
setup_vm_image() {
    print_status "INFO" "Setting up VM image..."
    
    # Create VM directory
    mkdir -p "$VM_DIR"
    
    # Check if image exists
    if [[ -f "$IMG_FILE" ]]; then
        print_status "INFO" "Image file already exists. Skipping download."
    else
        print_status "INFO" "Downloading image from: $IMG_URL"
        if wget --show-progress -q -O "$IMG_FILE.tmp" "$IMG_URL"; then
            mv "$IMG_FILE.tmp" "$IMG_FILE"
            print_status "SUCCESS" "Image downloaded successfully"
        else
            print_status "ERROR" "Failed to download image"
            return 1
        fi
    fi
    
    # Resize disk if needed
    if ! qemu-img info "$IMG_FILE" 2>/dev/null | grep -q "virtual size:.*$DISK_SIZE"; then
        print_status "INFO" "Resizing disk to $DISK_SIZE"
        if qemu-img resize "$IMG_FILE" "$DISK_SIZE" 2>/dev/null; then
            print_status "SUCCESS" "Disk resized successfully"
        else
            print_status "WARN" "Failed to resize disk. Creating new image..."
            qemu-img create -f qcow2 "$IMG_FILE" "$DISK_SIZE"
        fi
    fi
    
    # Create cloud-init config
    create_cloud_init "$VM_NAME"
}

# Create new VM via TUI
create_vm_tui() {
    local temp_file=$(mktemp)
    
    # Step 1: Select OS
    local os_options=()
    local os_index=1
    for os in "${!OS_OPTIONS[@]}"; do
        os_options+=("$os" "")
        ((os_index++))
    done
    
    dialog --clear --title "Select Operating System" \
        --menu "Choose an OS to install:" 20 60 12 \
        "${os_options[@]}" 2> "$temp_file"
    
    if [ $? -ne 0 ]; then
        rm -f "$temp_file"
        return 1
    fi
    
    local selected_os=$(cat "$temp_file")
    IFS='|' read -r OS_TYPE CODENAME IMG_URL DEFAULT_HOSTNAME DEFAULT_USERNAME DEFAULT_PASSWORD <<< "${OS_OPTIONS[$selected_os]}"
    
    # Step 2: VM Configuration
    dialog --clear --title "VM Configuration" \
        --form "Configure your virtual machine:" 20 60 8 \
        "VM Name:"         1 1 "$DEFAULT_HOSTNAME" 1 20 40 0 \
        "Hostname:"        2 1 "$DEFAULT_HOSTNAME" 2 20 40 0 \
        "Username:"        3 1 "$DEFAULT_USERNAME" 3 20 40 0 \
        "Password:"        4 1 "$DEFAULT_PASSWORD" 4 20 40 0 \
        "Memory (MB):"     5 1 "2048"             5 20 10 0 \
        "CPU Cores:"       6 1 "2"                6 20 10 0 \
        "Disk Size:"       7 1 "20G"              7 20 10 0 \
        "SSH Port:"        8 1 "2222"             8 20 10 0 \
        2> "$temp_file"
    
    if [ $? -ne 0 ]; then
        rm -f "$temp_file"
        return 1
    fi
    
    {
        read VM_NAME
        read HOSTNAME
        read USERNAME
        read PASSWORD
        read MEMORY
        read CPUS
        read DISK_SIZE
        read SSH_PORT
    } < "$temp_file"
    
    # Step 3: Additional Options
    dialog --clear --title "Additional Options" \
        --checklist "Select additional options:" 15 50 5 \
        1 "Enable GUI Mode" off \
        2 "Enable VNC Server (5900)" off \
        3 "Enable SPICE Protocol" off \
        4 "Enable VirGL 3D Acceleration" off \
        5 "Use UEFI Boot" off \
        2> "$temp_file"
    
    local options=$(cat "$temp_file")
    GUI_MODE=false
    [[ "$options" == *1* ]] && GUI_MODE=true
    
    # Step 4: Port Forwarding
    dialog --clear --title "Port Forwarding" \
        --inputbox "Additional port forwards (e.g., 8080:80,9000:9000):" 8 60 \
        2> "$temp_file"
    
    PORT_FORWARDS=$(cat "$temp_file")
    
    # Set file paths
    IMG_FILE="$VM_DIR/$VM_NAME.img"
    SEED_FILE="$VM_DIR/$VM_NAME-seed.iso"
    CREATED="$(date)"
    
    # Confirm creation
    dialog --clear --title "Confirm Creation" \
        --yesno "Create VM with following settings?\n\n\
${DISK} Name: $VM_NAME\n\
${TERM} OS: $selected_os\n\
${RAM} Memory: ${MEMORY}MB\n\
${CPU} CPUs: $CPUS\n\
${DISK} Disk: $DISK_SIZE\n\
${NET} SSH Port: $SSH_PORT\n\
${USER} Username: $USERNAME" 15 60
    
    if [ $? -eq 0 ]; then
        setup_vm_image
        save_vm_config
        
        dialog --clear --title "VM Created" \
            --msgbox "Virtual Machine '$VM_NAME' created successfully!\n\n\
${KEY} Username: $USERNAME\n\
${KEY} Password: $PASSWORD\n\
${NET} SSH: ssh -p $SSH_PORT $USERNAME@localhost\n\
${DISK} Location: $VM_DIR" 12 60
        
        print_status "SUCCESS" "VM '$VM_NAME' created successfully"
    fi
    
    rm -f "$temp_file"
}

# Show VM dashboard
show_dashboard() {
    while true; do
        local vms=($(get_vm_list))
        local vm_count=${#vms[@]}
        local running_vms=($(get_running_vms))
        local running_count=${#running_vms[@]}
        
        local menu_items=()
        local i=1
        
        # Add VM entries
        for vm in "${vms[@]}"; do
            local status="${RED}${STOP}${NC}"
            if is_vm_running "$vm"; then
                status="${GREEN}${ROCKET}${NC}"
            fi
            
            menu_items+=("$i" "$vm $status")
            ((i++))
        done
        
        # Add management options
        menu_items+=("C" "${PLUS} Create New VM")
        menu_items+=("S" "${GRAPH} System Stats")
        menu_items+=("L" "${SEARCH} View Logs")
        menu_items+=("Q" "Exit")
        
        print_header
        echo -e "${CYAN}📊 Dashboard${NC}"
        echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
        echo -e "${WHITE}Total VMs: ${GREEN}$vm_count${WHITE} | Running: ${GREEN}$running_count${WHITE} | Stopped: ${RED}$((vm_count - running_count))${NC}"
        echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
        echo
        
        # Display quick stats
        if [ $vm_count -gt 0 ]; then
            echo -e "${WHITE}Quick Stats:${NC}"
            for vm in "${vms[@]}"; do
                if load_vm_config "$vm" 2>/dev/null; then
                    local status_indicator="${RED}●${NC}"
                    if is_vm_running "$vm"; then
                        status_indicator="${GREEN}●${NC}"
                    fi
                    echo -e "  ${status_indicator} ${WHITE}$vm${NC} - ${CPU}$CPUS ${RAM}$MEMORY MB ${DISK}$DISK_SIZE ${NET}$SSH_PORT"
                fi
            done
            echo
        fi
        
        # Show menu using dialog
        local temp_file=$(mktemp)
        
        dialog --clear --title "VM Dashboard" \
            --menu "Select a VM or action:" 25 60 18 \
            "${menu_items[@]}" 2> "$temp_file"
        
        local choice=$(cat "$temp_file")
        rm -f "$temp_file"
        
        case $choice in
            [0-9]*)
                if [ "$choice" -le "$vm_count" ] && [ "$choice" -ge 1 ]; then
                    vm_action_menu "${vms[$((choice-1))]}"
                fi
                ;;
            "C")
                create_vm_tui
                ;;
            "S")
                show_system_stats
                ;;
            "L")
                view_logs
                ;;
            "Q")
                print_status "INFO" "Goodbye!"
                exit 0
                ;;
            *)
                print_status "ERROR" "Invalid selection"
                ;;
        esac
    done
}

# VM Action Menu
vm_action_menu() {
    local vm_name=$1
    
    while true; do
        load_vm_config "$vm_name"
        local is_running=false
        is_vm_running "$vm_name" && is_running=true
        
        local status_color=$RED
        local status_text="Stopped"
        local status_icon=$STOP
        if $is_running; then
            status_color=$GREEN
            status_text="Running"
            status_icon=$ROCKET
        fi
        
        print_header
        echo -e "${CYAN}VM Management: $vm_name${NC}"
        echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
        echo -e "Status: ${status_color}${status_icon} $status_text${NC}"
        echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
        echo
        
        # Show VM info
        echo -e "${WHITE}Basic Information:${NC}"
        echo -e "  ${TERM} OS: $OS_TYPE $CODENAME"
        echo -e "  ${USER} Hostname: $HOSTNAME"
        echo -e "  ${KEY} Username: $USERNAME"
        echo -e "  ${NET} SSH Port: $SSH_PORT"
        echo -e "  ${RAM} Memory: $MEMORY MB"
        echo -e "  ${CPU} CPUs: $CPUS"
        echo -e "  ${DISK} Disk: $DISK_SIZE"
        echo
        
        # Action menu using dialog
        local temp_file=$(mktemp)
        local menu_items=()
        
        if $is_running; then
            menu_items+=("1" "${STOP} Stop VM")
            menu_items+=("2" "${TERM} Open Console")
            menu_items+=("3" "${NET} Connect via SSH")
        else
            menu_items+=("1" "${ROCKET} Start VM")
        fi
        
        menu_items+=("4" "${GRAPH} Performance")
        menu_items+=("5" "${EDIT} Edit Configuration")
        menu_items+=("6" "${DISK} Resize Disk")
        menu_items+=("7" "${FIX} Fix Issues")
        menu_items+=("8" "${TRASH} Delete VM")
        menu_items+=("9" "${BACK} Back to Dashboard")
        
        dialog --clear --title "VM Actions: $vm_name" \
            --menu "Select an action:" 20 60 12 \
            "${menu_items[@]}" 2> "$temp_file"
        
        local choice=$(cat "$temp_file")
        rm -f "$temp_file"
        
        case $choice in
            1)
                if $is_running; then
                    stop_vm "$vm_name"
                else
                    start_vm "$vm_name"
                fi
                ;;
            2)
                if $is_running; then
                    open_vm_console "$vm_name"
                fi
                ;;
            3)
                if $is_running; then
                    connect_vm_ssh "$vm_name"
                fi
                ;;
            4)
                show_vm_performance "$vm_name"
                ;;
            5)
                edit_vm_config_tui "$vm_name"
                ;;
            6)
                resize_vm_disk_tui "$vm_name"
                ;;
            7)
                fix_vm_issues_tui "$vm_name"
                ;;
            8)
                delete_vm_tui "$vm_name"
                return 0
                ;;
            9)
                return 0
                ;;
            *)
                print_status "ERROR" "Invalid selection"
                ;;
        esac
        
        read -p "Press Enter to continue..."
    done
}

# Start VM
start_vm() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        # Check if already running
        if is_vm_running "$vm_name"; then
            dialog --clear --title "VM Running" \
                --msgbox "VM '$vm_name' is already running!" 8 40
            return 0
        fi
        
        # Check port availability
        if ss -tln 2>/dev/null | grep -q ":$SSH_PORT "; then
            dialog --clear --title "Port Conflict" \
                --msgbox "Port $SSH_PORT is already in use!" 8 40
            return 1
        fi
        
        # Check image file
        if [[ ! -f "$IMG_FILE" ]]; then
            dialog --clear --title "Missing Image" \
                --msgbox "VM image file not found!\n\n$IMG_FILE" 10 50
            return 1
        fi
        
        # Create seed if missing
        if [[ ! -f "$SEED_FILE" ]]; then
            create_cloud_init "$vm_name"
        fi
        
        # Build QEMU command
        local qemu_cmd=(
            qemu-system-x86_64
            -enable-kvm
            -m "$MEMORY"
            -smp "$CPUS"
            -cpu host
            -drive "file=$IMG_FILE,format=qcow2,if=virtio"
            -drive "file=$SEED_FILE,format=raw,if=virtio"
            -boot order=c
            -device virtio-net-pci,netdev=n0
            -netdev "user,id=n0,hostfwd=tcp::$SSH_PORT-:22"
            -device virtio-balloon-pci
            -object rng-random,filename=/dev/urandom,id=rng0
            -device virtio-rng-pci,rng=rng0
        )
        
        # Add port forwards
        if [[ -n "$PORT_FORWARDS" ]]; then
            IFS=',' read -ra forwards <<< "$PORT_FORWARDS"
            for forward in "${forwards[@]}"; do
                IFS=':' read -r host_port guest_port <<< "$forward"
                qemu_cmd+=(-device "virtio-net-pci,netdev=n${#qemu_cmd[@]}")
                qemu_cmd+=(-netdev "user,id=n${#qemu_cmd[@]},hostfwd=tcp::$host_port-:$guest_port")
            done
        fi
        
        # GUI or console mode
        if [[ "$GUI_MODE" == true ]]; then
            qemu_cmd+=(-vga virtio -display gtk,gl=on)
        else
            qemu_cmd+=(-nographic -serial mon:stdio)
        fi
        
        # Start in background
        dialog --clear --title "Starting VM" \
            --infobox "Starting VM '$vm_name'...\n\nPlease wait..." 8 40
        
        if "${qemu_cmd[@]}" &>> "$LOG_FILE" & then
            local qemu_pid=$!
            echo "$qemu_pid" > "$VM_DIR/$vm_name.pid"
            
            # Wait for VM to boot
            sleep 5
            
            dialog --clear --title "VM Started" \
                --msgbox "VM '$vm_name' started successfully!\n\n\
${NET} SSH: ssh -p $SSH_PORT $USERNAME@localhost\n\
${KEY} Username: $USERNAME\n\
${KEY} Password: $PASSWORD\n\
PID: $qemu_pid" 12 50
            
            print_status "SUCCESS" "VM '$vm_name' started with PID $qemu_pid"
        else
            dialog --clear --title "Start Failed" \
                --msgbox "Failed to start VM '$vm_name'!" 8 40
            print_status "ERROR" "Failed to start VM '$vm_name'"
            return 1
        fi
    fi
}

# Stop VM
stop_vm() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        if is_vm_running "$vm_name"; then
            dialog --clear --title "Stop VM" \
                --yesno "Stop VM '$vm_name'?" 8 40
            
            if [ $? -eq 0 ]; then
                local pid_file="$VM_DIR/$vm_name.pid"
                if [[ -f "$pid_file" ]]; then
                    local pid=$(cat "$pid_file")
                    kill "$pid" 2>/dev/null
                    sleep 2
                    
                    if kill -0 "$pid" 2>/dev/null; then
                        kill -9 "$pid"
                        print_status "WARN" "Forcefully terminated VM '$vm_name' (PID: $pid)"
                    fi
                    
                    rm -f "$pid_file"
                    dialog --clear --title "VM Stopped" \
                        --msgbox "VM '$vm_name' stopped successfully!" 8 40
                    print_status "SUCCESS" "VM '$vm_name' stopped"
                fi
            fi
        else
            dialog --clear --title "VM Not Running" \
                --msgbox "VM '$vm_name' is not running!" 8 40
        fi
    fi
}

# Show system statistics
show_system_stats() {
    local temp_file=$(mktemp)
    
    # Get system info
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
    local mem_info=$(free -h | awk '/^Mem:/ {print "Total: " $2 " | Used: " $3 " | Free: " $4}')
    local disk_info=$(df -h / | awk 'NR==2 {print "Total: " $2 " | Used: " $3 " | Free: " $4}')
    local load_avg=$(cat /proc/loadavg | awk '{print $1", "$2", "$3}')
    
    # Get QEMU processes
    local qemu_count=$(pgrep -c qemu-system || echo "0")
    local total_vms=$(get_vm_list | wc -w)
    local running_vms=$(get_running_vms | wc -w)
    
    dialog --clear --title "System Statistics" \
        --msgbox "\
System Information:
${CPU} CPU Usage: $cpu_usage%
${RAM} Memory: $mem_info
${DISK} Disk: $disk_info
📈 Load Average: $load_avg

VM Manager Statistics:
${ROCKET} Running VMs: $running_vms
${STOP} Stopped VMs: $((total_vms - running_vms))
📊 Total VMs: $total_vms
⚙️  QEMU Processes: $qemu_count

Log File: $LOG_FILE
VM Directory: $VM_DIR" 20 60
    
    rm -f "$temp_file"
}

# View logs
view_logs() {
    if [[ -f "$LOG_FILE" ]]; then
        dialog --clear --title "Log Viewer" \
            --textbox "$LOG_FILE" 25 80
    else
        dialog --clear --title "No Logs" \
            --msgbox "No log file found at: $LOG_FILE" 8 40
    fi
}

# Open VM console
open_vm_console() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        if is_vm_running "$vm_name"; then
            if [[ "$GUI_MODE" == true ]]; then
                dialog --clear --title "Console Info" \
                    --msgbox "VM '$vm_name' is running in GUI mode.\n\nThe QEMU window should be visible on your desktop." 10 50
            else
                dialog --clear --title "Console Warning" \
                    --msgbox "VM '$vm_name' is running in console mode.\n\nTo access the console, you need to attach to the QEMU process.\n\nPress Ctrl+A then X to exit the console." 12 50
                
                # Try to connect via screen if possible
                local pid_file="$VM_DIR/$vm_name.pid"
                if [[ -f "$pid_file" ]]; then
                    local pid=$(cat "$pid_file")
                    if [[ -e "/proc/$pid/fd/0" ]]; then
                        echo "Attempting to attach to VM console..."
                        echo "Press Ctrl+A then D to detach"
                        sleep 2
                        # This is a simplified approach - real console attachment is more complex
                    fi
                fi
            fi
        fi
    fi
}

# Connect via SSH
connect_vm_ssh() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        if is_vm_running "$vm_name"; then
            local ssh_cmd="ssh -p $SSH_PORT $USERNAME@localhost"
            
            dialog --clear --title "SSH Connection" \
                --msgbox "SSH command for '$vm_name':\n\n$ssh_cmd\n\nUsername: $USERNAME\nPassword: $PASSWORD\n\nCopy the command to connect via SSH." 14 60
            
            # Offer to execute the command
            dialog --clear --title "Execute SSH" \
                --yesno "Execute SSH command now?" 8 40
            
            if [ $? -eq 0 ]; then
                echo "Connecting to $vm_name via SSH..."
                eval "$ssh_cmd"
            fi
        else
            dialog --clear --title "VM Not Running" \
                --msgbox "VM '$vm_name' is not running!" 8 40
        fi
    fi
}

# Show VM performance
show_vm_performance() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        local temp_file=$(mktemp)
        
        if is_vm_running "$vm_name"; then
            local pid_file="$VM_DIR/$vm_name.pid"
            if [[ -f "$pid_file" ]]; then
                local pid=$(cat "$pid_file")
                
                # Get process stats
                local proc_stats=$(ps -p "$pid" -o pid,%cpu,%mem,rss,vsz,cmd --no-headers 2>/dev/null || echo "Process not found")
                
                # Get system stats
                local cpu_count=$(nproc)
                local total_mem=$(free -m | awk '/^Mem:/ {print $2}')
                local used_mem=$(free -m | awk '/^Mem:/ {print $3}')
                
                dialog --clear --title "Performance: $vm_name" \
                    --msgbox "\
VM Performance Metrics:
${CPU} Process PID: $pid
${CPU} CPU Cores Allocated: $CPUS / $cpu_count
${RAM} Memory Allocated: $MEMORY MB / ${total_mem}MB
${RAM} System Memory Used: ${used_mem}MB / ${total_mem}MB

Process Statistics:
$proc_stats

Configuration:
${DISK} Disk: $DISK_SIZE
${NET} SSH Port: $SSH_PORT
${TERM} GUI Mode: $GUI_MODE" 20 60
            fi
        else
            dialog --clear --title "VM Stopped" \
                --msgbox "VM '$vm_name' is not running.\n\nPerformance metrics only available when VM is running." 10 50
        fi
        
        rm -f "$temp_file"
    fi
}

# Edit VM configuration via TUI
edit_vm_config_tui() {
    local vm_name=$1
    
    while true; do
        load_vm_config "$vm_name"
        
        local temp_file=$(mktemp)
        
        dialog --clear --title "Edit VM: $vm_name" \
            --menu "Select parameter to edit:" 20 60 12 \
            1 "Hostname ($HOSTNAME)" \
            2 "Username ($USERNAME)" \
            3 "Password (****)" \
            4 "SSH Port ($SSH_PORT)" \
            5 "Memory ($MEMORY MB)" \
            6 "CPU Cores ($CPUS)" \
            7 "Disk Size ($DISK_SIZE)" \
            8 "GUI Mode ($GUI_MODE)" \
            9 "Port Forwards ($PORT_FORWARDS)" \
            0 "Save and Return" \
            2> "$temp_file"
        
        local choice=$(cat "$temp_file")
        rm -f "$temp_file"
        
        case $choice in
            1)
                dialog --clear --title "Edit Hostname" \
                    --inputbox "Enter new hostname:" 8 40 "$HOSTNAME" 2> "$temp_file"
                if [ $? -eq 0 ]; then
                    HOSTNAME=$(cat "$temp_file")
                fi
                ;;
            2)
                dialog --clear --title "Edit Username" \
                    --inputbox "Enter new username:" 8 40 "$USERNAME" 2> "$temp_file"
                if [ $? -eq 0 ]; then
                    USERNAME=$(cat "$temp_file")
                fi
                ;;
            3)
                dialog --clear --title "Edit Password" \
                    --passwordbox "Enter new password:" 8 40 2> "$temp_file"
                if [ $? -eq 0 ]; then
                    PASSWORD=$(cat "$temp_file")
                fi
                ;;
            4)
                dialog --clear --title "Edit SSH Port" \
                    --inputbox "Enter new SSH port:" 8 40 "$SSH_PORT" 2> "$temp_file"
                if [ $? -eq 0 ]; then
                    SSH_PORT=$(cat "$temp_file")
                fi
                ;;
            5)
                dialog --clear --title "Edit Memory" \
                    --inputbox "Enter memory in MB:" 8 40 "$MEMORY" 2> "$temp_file"
                if [ $? -eq 0 ]; then
                    MEMORY=$(cat "$temp_file")
                fi
                ;;
            6)
                dialog --clear --title "Edit CPU Cores" \
                    --inputbox "Enter number of CPU cores:" 8 40 "$CPUS" 2> "$temp_file"
                if [ $? -eq 0 ]; then
                    CPUS=$(cat "$temp_file")
                fi
                ;;
            7)
                dialog --clear --title "Edit Disk Size" \
                    --inputbox "Enter disk size (e.g., 50G):" 8 40 "$DISK_SIZE" 2> "$temp_file"
                if [ $? -eq 0 ]; then
                    DISK_SIZE=$(cat "$temp_file")
                fi
                ;;
            8)
                dialog --clear --title "Edit GUI Mode" \
                    --yesno "Enable GUI mode?" 8 40
                if [ $? -eq 0 ]; then
                    GUI_MODE=true
                else
                    GUI_MODE=false
                fi
                ;;
            9)
                dialog --clear --title "Edit Port Forwards" \
                    --inputbox "Enter port forwards (e.g., 8080:80,9000:9000):" 8 60 "$PORT_FORWARDS" 2> "$temp_file"
                if [ $? -eq 0 ]; then
                    PORT_FORWARDS=$(cat "$temp_file")
                fi
                ;;
            0)
                # Recreate seed image with new config
                create_cloud_init "$vm_name"
                save_vm_config
                
                dialog --clear --title "Configuration Saved" \
                    --msgbox "VM configuration saved successfully!" 8 40
                return 0
                ;;
            *)
                continue
                ;;
        esac
        
        rm -f "$temp_file"
    done
}

# Resize VM disk via TUI
resize_vm_disk_tui() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        if is_vm_running "$vm_name"; then
            dialog --clear --title "VM Running" \
                --msgbox "Cannot resize disk while VM is running!\n\nStop the VM first." 10 40
            return 1
        fi
        
        dialog --clear --title "Resize Disk" \
            --inputbox "Current size: $DISK_SIZE\nEnter new disk size (e.g., 50G):" 10 40 \
            2> "$temp_file"
        
        local new_size=$(cat "$temp_file")
        rm -f "$temp_file"
        
        if [[ -n "$new_size" ]]; then
            dialog --clear --title "Confirm Resize" \
                --yesno "Resize disk from $DISK_SIZE to $new_size?\n\nNote: This operation may take some time." 10 40
            
            if [ $? -eq 0 ]; then
                if qemu-img resize "$IMG_FILE" "$new_size"; then
                    DISK_SIZE="$new_size"
                    save_vm_config
                    
                    dialog --clear --title "Success" \
                        --msgbox "Disk resized successfully to $new_size!" 8 40
                    print_status "SUCCESS" "Resized disk for '$vm_name' to $new_size"
                else
                    dialog --clear --title "Error" \
                        --msgbox "Failed to resize disk!" 8 40
                    print_status "ERROR" "Failed to resize disk for '$vm_name'"
                fi
            fi
        fi
    fi
}

# Fix VM issues via TUI
fix_vm_issues_tui() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        local temp_file=$(mktemp)
        
        dialog --clear --title "Fix Issues: $vm_name" \
            --menu "Select issue to fix:" 15 50 6 \
            1 "Remove lock files" \
            2 "Recreate seed image" \
            3 "Kill stuck processes" \
            4 "Check disk integrity" \
            5 "Reset configuration" \
            0 "Cancel" \
            2> "$temp_file"
        
        local choice=$(cat "$temp_file")
        rm -f "$temp_file"
        
        case $choice in
            1)
                rm -f "${IMG_FILE}.lock" 2>/dev/null
                rm -f "${IMG_FILE}"*.lock 2>/dev/null
                dialog --clear --title "Success" \
                    --msgbox "Lock files removed!" 8 40
                ;;
            2)
                create_cloud_init "$vm_name"
                dialog --clear --title "Success" \
                    --msgbox "Seed image recreated!" 8 40
                ;;
            3)
                pkill -f "qemu-system.*$IMG_FILE" 2>/dev/null
                sleep 1
                if pgrep -f "qemu-system.*$IMG_FILE" >/dev/null; then
                    pkill -9 -f "qemu-system.*$IMG_FILE" 2>/dev/null
                    dialog --clear --title "Success" \
                        --msgbox "Stuck processes killed!" 8 40
                else
                    dialog --clear --title "Info" \
                        --msgbox "No stuck processes found." 8 40
                fi
                ;;
            4)
                if qemu-img check "$IMG_FILE"; then
                    dialog --clear --title "Success" \
                        --msgbox "Disk integrity check passed!" 8 40
                else
                    dialog --clear --title "Warning" \
                        --msgbox "Disk integrity check failed!\n\nConsider recreating the VM." 10 40
                fi
                ;;
            5)
                dialog --clear --title "Reset Configuration" \
                    --yesno "Reset VM configuration to defaults?\n\nThis will only reset config, not delete data." 10 40
                
                if [ $? -eq 0 ]; then
                    save_vm_config
                    dialog --clear --title "Success" \
                        --msgbox "Configuration reset!" 8 40
                fi
                ;;
            0)
                return 0
                ;;
        esac
    fi
}

# Delete VM via TUI
delete_vm_tui() {
    local vm_name=$1
    
    dialog --clear --title "Delete VM" \
        --yesno "WARNING: This will permanently delete VM '$vm_name' and all its data!\n\nAre you absolutely sure?" 12 50
    
    if [ $? -eq 0 ]; then
        if load_vm_config "$vm_name"; then
            # Stop if running
            if is_vm_running "$vm_name"; then
                stop_vm "$vm_name"
                sleep 2
            fi
            
            # Delete files
            rm -f "$IMG_FILE" "$SEED_FILE" "$VM_DIR/$vm_name.conf" \
                  "$VM_DIR/$vm_name.pid" "${IMG_FILE}.lock" 2>/dev/null
            
            dialog --clear --title "Success" \
                --msgbox "VM '$vm_name' deleted successfully!" 8 40
            
            print_status "INFO" "VM '$vm_name' deleted"
        fi
    else
        dialog --clear --title "Cancelled" \
            --msgbox "Deletion cancelled." 8 40
    fi
}

# Cleanup function
cleanup() {
    # Remove temporary files
    rm -f "$VM_DIR/user-data" "$VM_DIR/meta-data" 2>/dev/null
    log_message "INFO" "Script terminated"
}

# Main execution
main() {
    # Set trap for cleanup
    trap cleanup EXIT
    
    # Check dependencies
    check_dependencies
    
    # Initialize
    init_directories
    
    # Log start
    log_message "INFO" "VM Manager started"
    
    # Show dashboard
    show_dashboard
}

# Run main function
main
