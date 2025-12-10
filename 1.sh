#!/bin/bash
set -euo pipefail

# =============================
# Enhanced Multi-VM Manager
# =============================

# Function to display header
display_header() {
    clear
    cat << "EOF"
🚀🔧🖥️  ========================================================
     Enhanced QEMU VM Manager v2.0
        Complete Linux OS Edition
🖥️🔧🚀 ========================================================
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

# Function to check if image file is locked
check_image_lock() {
    local img_file=$1
    local vm_name=$2
    
    # Check if QEMU is already using this image
    if lsof "$img_file" 2>/dev/null | grep -q qemu-system; then
        print_status "WARN" "🔒 Image file $img_file is already in use by another QEMU process"
        
        # Find the process ID
        local pid=$(lsof "$img_file" 2>/dev/null | grep qemu-system | awk '{print $2}' | head -1)
        if [[ -n "$pid" ]]; then
            print_status "INFO" "🔍 Process ID using the image: $pid"
            
            # Check if it's our own VM
            if ps -p "$pid" -o cmd= | grep -q "$vm_name"; then
                print_status "INFO" "🤔 This appears to be the same VM already running"
                read -p "$(print_status "INPUT" "🔄 Kill existing process and restart? (y/N): ")" kill_choice
                if [[ "$kill_choice" =~ ^[Yy]$ ]]; then
                    kill "$pid"
                    sleep 2
                    if kill -0 "$pid" 2>/dev/null; then
                        kill -9 "$pid"
                        print_status "WARN" "⚠️  Forcefully terminated process $pid"
                    fi
                    return 0
                else
                    return 1
                fi
            else
                print_status "ERROR" "🚫 Another QEMU instance is using this image"
                return 1
            fi
        fi
        return 1
    fi
    
    # Check for lock files
    local lock_file="${img_file}.lock"
    if [[ -f "$lock_file" ]]; then
        print_status "WARN" "🔒 Lock file found: $lock_file"
        
        # Check if lock file is stale (older than 5 minutes)
        if [[ $(find "$lock_file" -mmin +5 2>/dev/null) ]]; then
            print_status "WARN" "⏰ Lock file appears stale (older than 5 minutes)"
            read -p "$(print_status "INPUT" "🗑️  Remove stale lock file? (y/N): ")" remove_lock
            if [[ "$remove_lock" =~ ^[Yy]$ ]]; then
                rm -f "$lock_file"
                print_status "SUCCESS" "✅ Removed stale lock file"
                return 0
            else
                return 1
            fi
        fi
        return 1
    fi
    return 0
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
                print_status "ERROR" "❌ VM name can only contain letters, numbers, hyphens, and underscores"
                return 1
            fi
            ;;
        "username")
            if ! [[ "$value" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
                print_status "ERROR" "❌ Username must start with a letter or underscore, and contain only letters, numbers, hyphens, and underscores"
                return 1
            fi
            ;;
    esac
    return 0
}

# Function to check dependencies
check_dependencies() {
    local deps=("qemu-system-x86_64" "wget" "cloud-localds" "qemu-img" "lsof")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_status "ERROR" "🔧 Missing dependencies: ${missing_deps[*]}"
        print_status "INFO" "💡 On Ubuntu/Debian, try: sudo apt install qemu-system cloud-image-utils wget lsof"
        exit 1
    fi
}

# Function to cleanup temporary files
cleanup() {
    if [ -f "user-data" ]; then rm -f "user-data"; fi
    if [ -f "meta-data" ]; then rm -f "meta-data"; fi
}

# Function to get all VM configurations
get_vm_list() {
    find "$VM_DIR" -name "*.conf" -exec basename {} .conf \; 2>/dev/null | sort
}

# Function to load VM configuration
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
        print_status "ERROR" "📂 Configuration for VM '$vm_name' not found"
        return 1
    fi
}

# Function to save VM configuration
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
    
    print_status "SUCCESS" "💾 Configuration saved to $config_file"
}

# Function to create new VM
create_new_vm() {
    print_status "INFO" "🆕 Creating a new VM"
    
    # OS Selection with pagination
    local os_count=${#OS_OPTIONS[@]}
    local page_size=15
    local page=0
    local total_pages=$(( (os_count + page_size - 1) / page_size ))
    
    while true; do
        display_header
        print_status "INFO" "🌍 Select an OS to set up (Page $((page + 1))/$total_pages):"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        local os_keys=("${!OS_OPTIONS[@]}")
        local start=$((page * page_size))
        local end=$((start + page_size - 1))
        
        if (( end >= os_count )); then
            end=$((os_count - 1))
        fi
        
        for ((i=start; i<=end; i++)); do
            local os="${os_keys[$i]}"
            printf "  %3d) %s\n" $((i+1)) "$os"
        done
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        if (( total_pages > 1 )); then
            echo "📖 Navigation: n=Next Page, p=Previous Page, q=Back to Main Menu"
        fi
        
        read -p "$(print_status "INPUT" "🎯 Enter choice (1-$os_count, n/p/q): ")" choice
        
        case "$choice" in
            [nN])
                if (( page < total_pages - 1 )); then
                    ((page++))
                    continue
                else
                    print_status "INFO" "📄 Already on the last page"
                    sleep 1
                    continue
                fi
                ;;
            [pP])
                if (( page > 0 )); then
                    ((page--))
                    continue
                else
                    print_status "INFO" "📄 Already on the first page"
                    sleep 1
                    continue
                fi
                ;;
            [qQ])
                return 1
                ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le $os_count ]; then
                    local os="${os_keys[$((choice-1))]}"
                    IFS='|' read -r OS_TYPE CODENAME IMG_URL DEFAULT_HOSTNAME DEFAULT_USERNAME DEFAULT_PASSWORD <<< "${OS_OPTIONS[$os]}"
                    break
                else
                    print_status "ERROR" "❌ Invalid selection. Try again."
                    sleep 2
                fi
                ;;
        esac
    done

    # Custom Inputs with validation
    while true; do
        read -p "$(print_status "INPUT" "🏷️  Enter VM name (default: $DEFAULT_HOSTNAME): ")" VM_NAME
        VM_NAME="${VM_NAME:-$DEFAULT_HOSTNAME}"
        if validate_input "name" "$VM_NAME"; then
            # Check if VM name already exists
            if [[ -f "$VM_DIR/$VM_NAME.conf" ]]; then
                print_status "ERROR" "⚠️  VM with name '$VM_NAME' already exists"
            else
                break
            fi
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "🏠 Enter hostname (default: $VM_NAME): ")" HOSTNAME
        HOSTNAME="${HOSTNAME:-$VM_NAME}"
        if validate_input "name" "$HOSTNAME"; then
            break
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "👤 Enter username (default: $DEFAULT_USERNAME): ")" USERNAME
        USERNAME="${USERNAME:-$DEFAULT_USERNAME}"
        if validate_input "username" "$USERNAME"; then
            break
        fi
    done

    while true; do
        read -s -p "$(print_status "INPUT" "🔑 Enter password (default: $DEFAULT_PASSWORD): ")" PASSWORD
        PASSWORD="${PASSWORD:-$DEFAULT_PASSWORD}"
        echo
        if [ -n "$PASSWORD" ]; then
            break
        else
            print_status "ERROR" "❌ Password cannot be empty"
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "💾 Disk size (default: 20G): ")" DISK_SIZE
        DISK_SIZE="${DISK_SIZE:-20G}"
        if validate_input "size" "$DISK_SIZE"; then
            break
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "🧠 Memory in MB (default: 2048): ")" MEMORY
        MEMORY="${MEMORY:-2048}"
        if validate_input "number" "$MEMORY"; then
            break
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "⚡ Number of CPUs (default: 2): ")" CPUS
        CPUS="${CPUS:-2}"
        if validate_input "number" "$CPUS"; then
            break
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "🔌 SSH Port (default: 2222): ")" SSH_PORT
        SSH_PORT="${SSH_PORT:-2222}"
        if validate_input "port" "$SSH_PORT"; then
            # Check if port is already in use
            if ss -tln 2>/dev/null | grep -q ":$SSH_PORT "; then
                print_status "ERROR" "🚫 Port $SSH_PORT is already in use"
            else
                break
            fi
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "🖥️  Enable GUI mode? (y/n, default: n): ")" gui_input
        GUI_MODE=false
        gui_input="${gui_input:-n}"
        if [[ "$gui_input" =~ ^[Yy]$ ]]; then 
            GUI_MODE=true
            break
        elif [[ "$gui_input" =~ ^[Nn]$ ]]; then
            break
        else
            print_status "ERROR" "❌ Please answer y or n"
        fi
    done

    # Additional network options
    read -p "$(print_status "INPUT" "🌐 Additional port forwards (e.g., 8080:80, press Enter for none): ")" PORT_FORWARDS

    IMG_FILE="$VM_DIR/$VM_NAME.img"
    SEED_FILE="$VM_DIR/$VM_NAME-seed.iso"
    CREATED="$(date)"

    # Download and setup VM image
    setup_vm_image
    
    # Save configuration
    save_vm_config
}

# Function to setup VM image
setup_vm_image() {
    print_status "INFO" "📥 Downloading and preparing image..."
    
    # Create VM directory if it doesn't exist
    mkdir -p "$VM_DIR"
    
    # Check if image already exists
    if [[ -f "$IMG_FILE" ]]; then
        print_status "INFO" "✅ Image file already exists. Skipping download."
    else
        print_status "INFO" "🌐 Downloading image from $IMG_URL..."
        if ! wget --progress=bar:force "$IMG_URL" -O "$IMG_FILE.tmp"; then
            print_status "ERROR" "❌ Failed to download image from $IMG_URL"
            print_status "INFO" "💡 Trying alternative download method..."
            if ! curl -L "$IMG_URL" -o "$IMG_FILE.tmp"; then
                print_status "ERROR" "❌ All download methods failed"
                exit 1
            fi
        fi
        mv "$IMG_FILE.tmp" "$IMG_FILE"
    fi
    
    # Resize the disk image if needed
    if ! qemu-img resize "$IMG_FILE" "$DISK_SIZE" 2>/dev/null; then
        print_status "WARN" "⚠️  Failed to resize disk image. Creating new image with specified size..."
        # Create a new image with the specified size
        rm -f "$IMG_FILE"
        qemu-img create -f qcow2 -F qcow2 -b "$IMG_FILE" "$IMG_FILE.tmp" "$DISK_SIZE" 2>/dev/null || \
        qemu-img create -f qcow2 "$IMG_FILE" "$DISK_SIZE"
        if [ -f "$IMG_FILE.tmp" ]; then
            mv "$IMG_FILE.tmp" "$IMG_FILE"
        fi
    fi

    # cloud-init configuration
    cat > user-data <<EOF
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

    cat > meta-data <<EOF
instance-id: iid-$VM_NAME
local-hostname: $HOSTNAME
EOF

    if ! cloud-localds "$SEED_FILE" user-data meta-data; then
        print_status "ERROR" "❌ Failed to create cloud-init seed image"
        exit 1
    fi
    
    print_status "SUCCESS" "🎉 VM '$VM_NAME' created successfully."
    print_status "INFO" "🔑 Login with: username=$USERNAME, password=$PASSWORD"
    print_status "INFO" "🔌 SSH: ssh -p $SSH_PORT $USERNAME@localhost"
}

# Function to start a VM
start_vm() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        # Check if image is already in use
        if ! check_image_lock "$IMG_FILE" "$vm_name"; then
            print_status "ERROR" "🔒 Cannot start VM: Image file is locked by another process"
            read -p "$(print_status "INPUT" "🔄 Do you want to force kill all QEMU processes using this image? (y/N): ")" force_kill
            if [[ "$force_kill" =~ ^[Yy]$ ]]; then
                pkill -f "qemu-system.*$IMG_FILE"
                sleep 2
                if pgrep -f "qemu-system.*$IMG_FILE" >/dev/null; then
                    pkill -9 -f "qemu-system.*$IMG_FILE"
                fi
                print_status "SUCCESS" "✅ Terminated processes using the image"
                # Remove any lock files
                rm -f "${IMG_FILE}.lock" 2>/dev/null
            else
                return 1
            fi
        fi
        
        # Check if VM is already running
        if is_vm_running "$vm_name"; then
            print_status "WARN" "⚠️  VM '$vm_name' is already running"
            read -p "$(print_status "INPUT" "🔄 Stop and restart? (y/N): ")" restart_choice
            if [[ "$restart_choice" =~ ^[Yy]$ ]]; then
                stop_vm "$vm_name"
                sleep 2
            else
                return 1
            fi
        fi
        
        print_status "INFO" "🚀 Starting VM: $vm_name"
        print_status "INFO" "🔌 SSH: ssh -p $SSH_PORT $USERNAME@localhost"
        print_status "INFO" "🔑 Password: $PASSWORD"
        
        # Check if image file exists
        if [[ ! -f "$IMG_FILE" ]]; then
            print_status "ERROR" "❌ VM image file not found: $IMG_FILE"
            return 1
        fi
        
        # Check if seed file exists
        if [[ ! -f "$SEED_FILE" ]]; then
            print_status "WARN" "⚠️  Seed file not found, recreating..."
            setup_vm_image
        fi
        
        # Base QEMU command
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
        )

        # Add port forwards if specified
        if [[ -n "$PORT_FORWARDS" ]]; then
            IFS=',' read -ra forwards <<< "$PORT_FORWARDS"
            for forward in "${forwards[@]}"; do
                IFS=':' read -r host_port guest_port <<< "$forward"
                qemu_cmd+=(-device "virtio-net-pci,netdev=n${#qemu_cmd[@]}")
                qemu_cmd+=(-netdev "user,id=n${#qemu_cmd[@]},hostfwd=tcp::$host_port-:$guest_port")
            done
        fi

        # Add GUI or console mode
        if [[ "$GUI_MODE" == true ]]; then
            qemu_cmd+=(-vga virtio -display gtk,gl=on)
            print_status "INFO" "🖥️  Starting in GUI mode..."
        else
            qemu_cmd+=(-nographic -serial mon:stdio)
            print_status "INFO" "📟 Starting in console mode..."
            print_status "INFO" "🛑 Press Ctrl+A then X to exit QEMU console"
        fi

        # Add performance enhancements
        qemu_cmd+=(
            -device virtio-balloon-pci
            -object rng-random,filename=/dev/urandom,id=rng0
            -device virtio-rng-pci,rng=rng0
        )

        print_status "INFO" "⚡ Starting QEMU..."
        echo "📊 Configuration: ${MEMORY}MB RAM, ${CPUS} CPUs, ${DISK_SIZE} disk"
        
        # Start the VM
        if ! "${qemu_cmd[@]}"; then
            print_status "ERROR" "❌ Failed to start VM. There might be a problem with the image file or configuration."
            # Try to clean up lock files
            rm -f "${IMG_FILE}.lock" 2>/dev/null
            return 1
        fi
        
        print_status "INFO" "🛑 VM $vm_name has been shut down"
    fi
}

# Function to delete a VM
delete_vm() {
    local vm_name=$1
    
    print_status "WARN" "⚠️  ⚠️  ⚠️  This will permanently delete VM '$vm_name' and all its data!"
    read -p "$(print_status "INPUT" "🗑️  Are you sure? (y/N): ")" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if load_vm_config "$vm_name"; then
            # Check if VM is running
            if is_vm_running "$vm_name"; then
                print_status "WARN" "⚠️  VM is currently running. Stopping it first..."
                stop_vm "$vm_name"
                sleep 2
            fi
            
            rm -f "$IMG_FILE" "$SEED_FILE" "$VM_DIR/$vm_name.conf" "${IMG_FILE}.lock" 2>/dev/null
            print_status "SUCCESS" "✅ VM '$vm_name' has been deleted"
        fi
    else
        print_status "INFO" "👍 Deletion cancelled"
    fi
}

# Function to show VM info
show_vm_info() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        echo
        print_status "INFO" "📊 VM Information: $vm_name"
        echo "🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹"
        echo "🌍 OS: $OS_TYPE"
        echo "🏷️  Hostname: $HOSTNAME"
        echo "👤 Username: $USERNAME"
        echo "🔑 Password: $PASSWORD"
        echo "🔌 SSH Port: $SSH_PORT"
        echo "🧠 Memory: $MEMORY MB"
        echo "⚡ CPUs: $CPUS"
        echo "💾 Disk: $DISK_SIZE"
        echo "🖥️  GUI Mode: $GUI_MODE"
        echo "🌐 Port Forwards: ${PORT_FORWARDS:-None}"
        echo "📅 Created: $CREATED"
        echo "💿 Image File: $IMG_FILE"
        echo "🌱 Seed File: $SEED_FILE"
        
        # Show lock status
        if check_image_lock "$IMG_FILE" "$vm_name" >/dev/null 2>&1; then
            echo "🔓 Image Status: Unlocked"
        else
            echo "🔒 Image Status: Locked (possibly in use)"
        fi
        
        # Show if VM is running
        if is_vm_running "$vm_name"; then
            echo "🚀 Status: Running"
        else
            echo "💤 Status: Stopped"
        fi
        
        echo "🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹"
        echo
        read -p "$(print_status "INPUT" "⏎ Press Enter to continue...")"
    fi
}

# Function to check if VM is running
is_vm_running() {
    local vm_name=$1
    
    # First try to find by image file
    if pgrep -f "qemu-system.*$vm_name" >/dev/null; then
        return 0
    fi
    
    # Also check by image file path
    if load_vm_config "$vm_name" 2>/dev/null; then
        if pgrep -f "qemu-system.*$IMG_FILE" >/dev/null; then
            return 0
        fi
    fi
    
    return 1
}

# Function to stop a running VM
stop_vm() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        if is_vm_running "$vm_name"; then
            print_status "INFO" "🛑 Stopping VM: $vm_name"
            
            # Try graceful shutdown first
            pkill -f "qemu-system.*$IMG_FILE"
            sleep 2
            
            # Check if it stopped
            if is_vm_running "$vm_name"; then
                print_status "WARN" "⚠️  VM did not stop gracefully, forcing termination..."
                pkill -9 -f "qemu-system.*$IMG_FILE"
                sleep 1
            fi
            
            # Clean up lock files
            rm -f "${IMG_FILE}.lock" 2>/dev/null
            
            if is_vm_running "$vm_name"; then
                print_status "ERROR" "❌ Failed to stop VM"
                return 1
            else
                print_status "SUCCESS" "✅ VM $vm_name stopped"
            fi
        else
            print_status "INFO" "💤 VM $vm_name is not running"
            # Still try to clean up any lock files
            rm -f "${IMG_FILE}.lock" 2>/dev/null
        fi
    fi
}

# Function to edit VM configuration
edit_vm_config() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        print_status "INFO" "✏️  Editing VM: $vm_name"
        
        while true; do
            echo "📝 What would you like to edit?"
            echo "  1) 🏷️  Hostname"
            echo "  2) 👤 Username"
            echo "  3) 🔑 Password"
            echo "  4) 🔌 SSH Port"
            echo "  5) 🖥️  GUI Mode"
            echo "  6) 🌐 Port Forwards"
            echo "  7) 🧠 Memory (RAM)"
            echo "  8) ⚡ CPU Count"
            echo "  9) 💾 Disk Size"
            echo "  0) ↩️  Back to main menu"
            
            read -p "$(print_status "INPUT" "🎯 Enter your choice: ")" edit_choice
            
            case $edit_choice in
                1)
                    while true; do
                        read -p "$(print_status "INPUT" "🏷️  Enter new hostname (current: $HOSTNAME): ")" new_hostname
                        new_hostname="${new_hostname:-$HOSTNAME}"
                        if validate_input "name" "$new_hostname"; then
                            HOSTNAME="$new_hostname"
                            break
                        fi
                    done
                    ;;
                2)
                    while true; do
                        read -p "$(print_status "INPUT" "👤 Enter new username (current: $USERNAME): ")" new_username
                        new_username="${new_username:-$USERNAME}"
                        if validate_input "username" "$new_username"; then
                            USERNAME="$new_username"
                            break
                        fi
                    done
                    ;;
                3)
                    while true; do
                        read -s -p "$(print_status "INPUT" "🔑 Enter new password (current: ****): ")" new_password
                        new_password="${new_password:-$PASSWORD}"
                        echo
                        if [ -n "$new_password" ]; then
                            PASSWORD="$new_password"
                            break
                        else
                            print_status "ERROR" "❌ Password cannot be empty"
                        fi
                    done
                    ;;
                4)
                    while true; do
                        read -p "$(print_status "INPUT" "🔌 Enter new SSH port (current: $SSH_PORT): ")" new_ssh_port
                        new_ssh_port="${new_ssh_port:-$SSH_PORT}"
                        if validate_input "port" "$new_ssh_port"; then
                            # Check if port is already in use
                            if [ "$new_ssh_port" != "$SSH_PORT" ] && ss -tln 2>/dev/null | grep -q ":$new_ssh_port "; then
                                print_status "ERROR" "🚫 Port $new_ssh_port is already in use"
                            else
                                SSH_PORT="$new_ssh_port"
                                break
                            fi
                        fi
                    done
                    ;;
                5)
                    while true; do
                        read -p "$(print_status "INPUT" "🖥️  Enable GUI mode? (y/n, current: $GUI_MODE): ")" gui_input
                        gui_input="${gui_input:-}"
                        if [[ "$gui_input" =~ ^[Yy]$ ]]; then 
                            GUI_MODE=true
                            break
                        elif [[ "$gui_input" =~ ^[Nn]$ ]]; then
                            GUI_MODE=false
                            break
                        elif [ -z "$gui_input" ]; then
                            # Keep current value if user just pressed Enter
                            break
                        else
                            print_status "ERROR" "❌ Please answer y or n"
                        fi
                    done
                    ;;
                6)
                    read -p "$(print_status "INPUT" "🌐 Additional port forwards (current: ${PORT_FORWARDS:-None}): ")" new_port_forwards
                    PORT_FORWARDS="${new_port_forwards:-$PORT_FORWARDS}"
                    ;;
                7)
                    while true; do
                        read -p "$(print_status "INPUT" "🧠 Enter new memory in MB (current: $MEMORY): ")" new_memory
                        new_memory="${new_memory:-$MEMORY}"
                        if validate_input "number" "$new_memory"; then
                            MEMORY="$new_memory"
                            break
                        fi
                    done
                    ;;
                8)
                    while true; do
                        read -p "$(print_status "INPUT" "⚡ Enter new CPU count (current: $CPUS): ")" new_cpus
                        new_cpus="${new_cpus:-$CPUS}"
                        if validate_input "number" "$new_cpus"; then
                            CPUS="$new_cpus"
                            break
                        fi
                    done
                    ;;
                9)
                    while true; do
                        read -p "$(print_status "INPUT" "💾 Enter new disk size (current: $DISK_SIZE): ")" new_disk_size
                        new_disk_size="${new_disk_size:-$DISK_SIZE}"
                        if validate_input "size" "$new_disk_size"; then
                            DISK_SIZE="$new_disk_size"
                            break
                        fi
                    done
                    ;;
                0)
                    return 0
                    ;;
                *)
                    print_status "ERROR" "❌ Invalid selection"
                    continue
                    ;;
            esac
            
            # Recreate seed image with new configuration if user/password/hostname changed
            if [[ "$edit_choice" -eq 1 || "$edit_choice" -eq 2 || "$edit_choice" -eq 3 ]]; then
                print_status "INFO" "🔄 Updating cloud-init configuration..."
                setup_vm_image
            fi
            
            # Save configuration
            save_vm_config
            
            read -p "$(print_status "INPUT" "🔄 Continue editing? (y/N): ")" continue_editing
            if [[ ! "$continue_editing" =~ ^[Yy]$ ]]; then
                break
            fi
        done
    fi
}

# Function to resize VM disk
resize_vm_disk() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        # Check if VM is running
        if is_vm_running "$vm_name"; then
            print_status "ERROR" "❌ Cannot resize disk while VM is running. Please stop the VM first."
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
                
                # Check if new size is smaller than current (not recommended)
                local current_size_num=${DISK_SIZE%[GgMm]}
                local new_size_num=${new_disk_size%[GgMm]}
                local current_unit=${DISK_SIZE: -1}
                local new_unit=${new_disk_size: -1}
                
                # Convert both to MB for comparison
                if [[ "$current_unit" =~ [Gg] ]]; then
                    current_size_num=$((current_size_num * 1024))
                fi
                if [[ "$new_unit" =~ [Gg] ]]; then
                    new_size_num=$((new_size_num * 1024))
                fi
                
                if [[ $new_size_num -lt $current_size_num ]]; then
                    print_status "WARN" "⚠️  Shrinking disk size is not recommended and may cause data loss!"
                    read -p "$(print_status "INPUT" "⚠️  Are you sure you want to continue? (y/N): ")" confirm_shrink
                    if [[ ! "$confirm_shrink" =~ ^[Yy]$ ]]; then
                        print_status "INFO" "👍 Disk resize cancelled."
                        return 0
                    fi
                fi
                
                # Resize the disk
                print_status "INFO" "📈 Resizing disk to $new_disk_size..."
                if qemu-img resize "$IMG_FILE" "$new_disk_size"; then
                    DISK_SIZE="$new_disk_size"
                    save_vm_config
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

# Function to show VM performance metrics
show_vm_performance() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        if is_vm_running "$vm_name"; then
            print_status "INFO" "📊 Performance metrics for VM: $vm_name"
            echo "📈📈📈📈📈📈📈📈📈📈📈📈📈📈📈"
            
            # Get QEMU process ID
            local qemu_pid=$(pgrep -f "qemu-system.*$IMG_FILE")
            if [[ -n "$qemu_pid" ]]; then
                # Show process stats
                echo "⚡ QEMU Process Stats:"
                ps -p "$qemu_pid" -o pid,%cpu,%mem,sz,rss,vsz,cmd --no-headers
                echo
                
                # Show memory usage
                echo "🧠 Memory Usage:"
                free -h
                echo
                
                # Show disk usage
                echo "💾 Disk Usage:"
                df -h "$IMG_FILE" 2>/dev/null || du -h "$IMG_FILE"
            else
                print_status "ERROR" "❌ Could not find QEMU process for VM $vm_name"
            fi
        else
            print_status "INFO" "💤 VM $vm_name is not running"
            echo "⚙️  Configuration:"
            echo "  🧠 Memory: $MEMORY MB"
            echo "  ⚡ CPUs: $CPUS"
            echo "  💾 Disk: $DISK_SIZE"
        fi
        echo "📈📈📈📈📈📈📈📈📈📈📈📈📈📈📈"
        read -p "$(print_status "INPUT" "⏎ Press Enter to continue...")"
    fi
}

# Function to fix VM issues
fix_vm_issues() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        print_status "INFO" "🔧 Fixing issues for VM: $vm_name"
        
        echo "🔧 Select issue to fix:"
        echo "  1) 🔓 Remove lock files"
        echo "  2) 🗑️  Recreate seed image"
        echo "  3) 🔄 Recreate configuration"
        echo "  4) 💀 Kill stuck processes"
        echo "  0) ↩️  Back"
        
        read -p "$(print_status "INPUT" "🎯 Enter your choice: ")" fix_choice
        
        case $fix_choice in
            1)
                print_status "INFO" "🔓 Removing lock files..."
                rm -f "${IMG_FILE}.lock" 2>/dev/null
                rm -f "${IMG_FILE}"*.lock 2>/dev/null
                print_status "SUCCESS" "✅ Lock files removed"
                ;;
            2)
                print_status "INFO" "🔄 Recreating seed image..."
                if [[ -f "$SEED_FILE" ]]; then
                    rm -f "$SEED_FILE"
                fi
                setup_vm_image
                print_status "SUCCESS" "✅ Seed image recreated"
                ;;
            3)
                print_status "INFO" "🔄 Recreating configuration..."
                save_vm_config
                print_status "SUCCESS" "✅ Configuration recreated"
                ;;
            4)
                print_status "INFO" "💀 Killing stuck processes..."
                pkill -f "qemu-system.*$IMG_FILE" 2>/dev/null
                sleep 1
                if pgrep -f "qemu-system.*$IMG_FILE" >/dev/null; then
                    pkill -9 -f "qemu-system.*$IMG_FILE" 2>/dev/null
                    print_status "SUCCESS" "✅ Forcefully killed stuck processes"
                else
                    print_status "INFO" "💤 No stuck processes found"
                fi
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

# Function to search OS by name
search_os() {
    local query=$1
    local results=()
    
    for os in "${!OS_OPTIONS[@]}"; do
        if [[ "$os" =~ $query ]] || [[ "${OS_OPTIONS[$os]}" =~ $query ]]; then
            results+=("$os")
        fi
    done
    
    echo "${results[@]}"
}

# Main menu function
main_menu() {
    while true; do
        display_header
        
        local vms=($(get_vm_list))
        local vm_count=${#vms[@]}
        
        if [ $vm_count -gt 0 ]; then
            print_status "INFO" "📁 Found $vm_count existing VM(s):"
            for i in "${!vms[@]}"; do
                local status="💤"
                if is_vm_running "${vms[$i]}"; then
                    status="🚀"
                fi
                printf "  %2d) %s %s\n" $((i+1)) "${vms[$i]}" "$status"
            done
            echo
        fi
        
        echo "📋 Main Menu:"
        echo "  1) 🆕 Create a new VM"
        if [ $vm_count -gt 0 ]; then
            echo "  2) 🚀 Start a VM"
            echo "  3) 🛑 Stop a VM"
            echo "  4) 📊 Show VM info"
            echo "  5) ✏️  Edit VM configuration"
            echo "  6) 🗑️  Delete a VM"
            echo "  7) 📈 Resize VM disk"
            echo "  8) 📊 Show VM performance"
            echo "  9) 🔧 Fix VM issues"
        fi
        echo "  S) 🔍 Search OS"
        echo "  L) 📋 List all available OS"
        echo "  0) 👋 Exit"
        echo
        
        read -p "$(print_status "INPUT" "🎯 Enter your choice: ")" choice
        
        case $choice in
            1)
                create_new_vm
                ;;
            2)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "🚀 Enter VM number to start: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        start_vm "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            3)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "🛑 Enter VM number to stop: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        stop_vm "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            4)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "📊 Enter VM number to show info: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        show_vm_info "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            5)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "✏️  Enter VM number to edit: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        edit_vm_config "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            6)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "🗑️  Enter VM number to delete: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        delete_vm "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            7)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "📈 Enter VM number to resize disk: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        resize_vm_disk "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            8)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "📊 Enter VM number to show performance: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        show_vm_performance "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            9)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "🔧 Enter VM number to fix issues: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        fix_vm_issues "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            [Ss])
                display_header
                read -p "$(print_status "INPUT" "🔍 Search for OS (name or keyword): ")" search_query
                local results=($(search_os "$search_query"))
                if [ ${#results[@]} -gt 0 ]; then
                    print_status "INFO" "🔍 Found ${#results[@]} matching OS:"
                    for i in "${!results[@]}"; do
                        echo "  $((i+1))) ${results[$i]}"
                    done
                else
                    print_status "INFO" "❌ No matching OS found"
                fi
                read -p "$(print_status "INPUT" "⏎ Press Enter to continue...")"
                ;;
            [Ll])
                display_header
                print_status "INFO" "📋 Available Linux Distributions (${#OS_OPTIONS[@]} total):"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                
                # Group by distribution family
                declare -A os_families
                for os in "${!OS_OPTIONS[@]}"; do
                    family=$(echo "${OS_OPTIONS[$os]}" | cut -d'|' -f1)
                    os_families["$family"]+="$os"$'\n'
                done
                
                for family in "${!os_families[@]}"; do
                    echo "🎯 $family:"
                    echo "$os_families[$family]" | sort | while read -r os; do
                        if [ -n "$os" ]; then
                            echo "    • $os"
                        fi
                    done
                    echo
                done
                
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                read -p "$(print_status "INPUT" "⏎ Press Enter to continue...")"
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
VM_DIR="${VM_DIR:-$HOME/vms}"
mkdir -p "$VM_DIR"

# ============================================================================
# COMPLETE LINUX OS LIST - All Major Distributions
# ============================================================================
# Format: "OS Name|codename|image_url|default_vm_name|default_username|default_password"
declare -A OS_OPTIONS=(
    # Ubuntu Family
    ["Ubuntu 18.04 LTS (Bionic Beaver)"]="ubuntu|bionic|https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img|ubuntu18|ubuntu|ubuntu"
    ["Ubuntu 20.04 LTS (Focal Fossa)"]="ubuntu|focal|https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img|ubuntu20|ubuntu|ubuntu"
    ["Ubuntu 22.04 LTS (Jammy Jellyfish)"]="ubuntu|jammy|https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img|ubuntu22|ubuntu|ubuntu"
    ["Ubuntu 24.04 LTS (Noble Numbat)"]="ubuntu|noble|https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img|ubuntu24|ubuntu|ubuntu"
    ["Ubuntu 24.10 (Oracular Oriole)"]="ubuntu|oracular|https://cloud-images.ubuntu.com/oracular/current/oracular-server-cloudimg-amd64.img|ubuntu24.10|ubuntu|ubuntu"
    ["Ubuntu Minimal 22.04"]="ubuntu|jammy-minimal|https://cloud-images.ubuntu.com/minimal/releases/jammy/release/ubuntu-22.04-minimal-cloudimg-amd64.img|ubuntu22-minimal|ubuntu|ubuntu"
    ["Ubuntu Server 24.04"]="ubuntu|noble-server|https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-amd64.img|ubuntu24-server|ubuntu|ubuntu"

    # Debian Family
    ["Debian 10 (Buster)"]="debian|buster|https://cloud.debian.org/images/cloud/buster/latest/debian-10-generic-amd64.qcow2|debian10|debian|debian"
    ["Debian 11 (Bullseye)"]="debian|bullseye|https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2|debian11|debian|debian"
    ["Debian 12 (Bookworm)"]="debian|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|debian12|debian|debian"
    ["Debian 13 (Trixie)"]="debian|trixie|https://cloud.debian.org/images/cloud/trixie/daily/latest/debian-13-generic-amd64-daily.qcow2|debian13|debian|debian"
    ["Debian Testing (Trixie)"]="debian|trixie-testing|https://cloud.debian.org/images/cloud/trixie/daily/latest/debian-13-generic-amd64-daily.qcow2|debian-testing|debian|debian"
    ["Debian Unstable (Sid)"]="debian|sid|https://cloud.debian.org/images/cloud/sid/daily/latest/debian-sid-generic-amd64-daily.qcow2|debian-sid|debian|debian"

    # Fedora Family
    ["Fedora 38"]="fedora|38|https://download.fedoraproject.org/pub/fedora/linux/releases/38/Cloud/x86_64/images/Fedora-Cloud-Base-38-1.6.x86_64.qcow2|fedora38|fedora|fedora"
    ["Fedora 39"]="fedora|39|https://download.fedoraproject.org/pub/fedora/linux/releases/39/Cloud/x86_64/images/Fedora-Cloud-Base-39-1.5.x86_64.qcow2|fedora39|fedora|fedora"
    ["Fedora 40"]="fedora|40|https://download.fedoraproject.org/pub/fedora/linux/releases/40/Cloud/x86_64/images/Fedora-Cloud-Base-40-1.14.x86_64.qcow2|fedora40|fedora|fedora"
    ["Fedora 41"]="fedora|41|https://download.fedoraproject.org/pub/fedora/linux/development/41/Cloud/x86_64/images/Fedora-Cloud-Base-41-20240923.0.x86_64.qcow2|fedora41|fedora|fedora"
    ["Fedora Rawhide"]="fedora|rawhide|https://download.fedoraproject.org/pub/fedora/linux/development/rawhide/Cloud/x86_64/images/Fedora-Cloud-Base-Rawhide-20240923.n.0.x86_64.qcow2|fedora-rawhide|fedora|fedora"
    ["Fedora Silverblue 40"]="fedora|silverblue40|https://download.fedoraproject.org/pub/fedora/linux/releases/40/Cloud/x86_64/images/Fedora-Silverblue-ostree-x86_64-40-1.14.qcow2|fedora-silverblue40|fedora|fedora"

    # CentOS Family
    ["CentOS Stream 8"]="centos|stream8|https://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2|centos8|centos|centos"
    ["CentOS Stream 9"]="centos|stream9|https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2|centos9|centos|centos"
    ["CentOS 7"]="centos|7|https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2|centos7|centos|centos"

    # AlmaLinux Family
    ["AlmaLinux 8"]="almalinux|8|https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2|almalinux8|alma|alma"
    ["AlmaLinux 9"]="almalinux|9|https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2|almalinux9|alma|alma"
    ["AlmaLinux 10"]="almalinux|10|https://repo.almalinux.org/almalinux/10/cloud/x86_64/images/AlmaLinux-10-GenericCloud-beta-1.x86_64.qcow2|almalinux10|alma|alma"

    # Rocky Linux Family
    ["Rocky Linux 8"]="rockylinux|8|https://download.rockylinux.org/pub/rocky/8/images/x86_64/Rocky-8-GenericCloud.latest.x86_64.qcow2|rocky8|rocky|rocky"
    ["Rocky Linux 9"]="rockylinux|9|https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2|rocky9|rocky|rocky"
    ["Rocky Linux 10"]="rockylinux|10|https://download.rockylinux.org/pub/rocky/10/images/x86_64/Rocky-10-GenericCloud-Beta.latest.x86_64.qcow2|rocky10|rocky|rocky"

    # OpenSUSE Family
    ["openSUSE Leap 15.5"]="opensuse|leap15.5|https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.5/images/openSUSE-Leap-15.5.x86_64-NoCloud.qcow2|opensuse-leap15.5|opensuse|opensuse"
    ["openSUSE Leap 15.6"]="opensuse|leap15.6|https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.6/images/openSUSE-Leap-15.6.x86_64-NoCloud.qcow2|opensuse-leap15.6|opensuse|opensuse"
    ["openSUSE Tumbleweed"]="opensuse|tumbleweed|https://download.opensuse.org/repositories/Cloud:/Images:/openSUSE-Tumbleweed/images/openSUSE-Tumbleweed.x86_64-NoCloud.qcow2|opensuse-tumbleweed|opensuse|opensuse"
    ["openSUSE MicroOS"]="opensuse|microos|https://download.opensuse.org/repositories/Cloud:/Images:/openSUSE-MicroOS/images/openSUSE-MicroOS.x86_64-NoCloud.qcow2|opensuse-microos|opensuse|opensuse"

    # SUSE Linux Enterprise
    ["SLE Micro 5.5"]="sle|micro5.5|https://download.suse.com/amd64/slemicro/5.5/slemicro.x86_64-5.5.0-BYOS.qcow2|sle-micro55|suse|linux"
    ["SLE Micro 6.0"]="sle|micro6.0|https://download.suse.com/amd64/slemicro/6.0/slemicro.x86_64-6.0.0-BYOS.qcow2|sle-micro60|suse|linux"

    # Arch Linux Family
    ["Arch Linux"]="arch|latest|https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2|archlinux|arch|arch"
    ["Arch Linux (Alternative)"]="arch|latest-alt|https://cloud.archlinux.org/images/latest/Arch-Linux-x86_64-cloudimg.qcow2|archlinux-alt|arch|arch"
    ["Artix Linux"]="artix|latest|https://mirror.artixlinux.org/iso/cloud/artix-linux-openrc-cloudimg-x86_64.qcow2|artixlinux|artix|artix"

    # Gentoo Family
    ["Gentoo (Generic Cloud)"]="gentoo|latest|https://gentoo.osuosl.org/experimental/amd64/openstack/gentoo-openstack-amd64-latest.qcow2|gentoo|gentoo|gentoo"
    ["Gentoo (Systemd)"]="gentoo|systemd|https://gentoo.osuosl.org/experimental/amd64/openstack/gentoo-openstack-systemd-amd64-latest.qcow2|gentoo-systemd|gentoo|gentoo"

    # Void Linux
    ["Void Linux (musl)"]="void|musl|https://repo-default.voidlinux.org/live/current/void-x86_64-musl-ROOTFS-20241001.tar.xz|void-musl|void|voidlinux"
    ["Void Linux (glibc)"]="void|glibc|https://repo-default.voidlinux.org/live/current/void-x86_64-ROOTFS-20241001.tar.xz|void-glibc|void|voidlinux"

    # Alpine Linux
    ["Alpine Linux 3.18"]="alpine|3.18|https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/x86_64/alpine-standard-3.18.0-x86_64.iso|alpine318|alpine|alpine"
    ["Alpine Linux 3.19"]="alpine|3.19|https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-standard-3.19.0-x86_64.iso|alpine319|alpine|alpine"
    ["Alpine Linux 3.20"]="alpine|3.20|https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86_64/alpine-standard-3.20.0-x86_64.iso|alpine320|alpine|alpine"
    ["Alpine Linux Edge"]="alpine|edge|https://dl-cdn.alpinelinux.org/alpine/edge/releases/x86_64/alpine-standard-edge-x86_64.iso|alpine-edge|alpine|alpine"

    # NixOS
    ["NixOS 24.05"]="nixos|24.05|https://channels.nixos.org/nixos-24.05/latest-nixos-minimal-x86_64-linux.iso|nixos-2405|nixos|nixos"
    ["NixOS Unstable"]="nixos|unstable|https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-x86_64-linux.iso|nixos-unstable|nixos|nixos"

    # Clear Linux
    ["Clear Linux"]="clearlinux|latest|https://cdn.download.clearlinux.org/releases/current/clear/clear-cloudguest.img.xz|clearlinux|clear|clear"

    # Oracle Linux
    ["Oracle Linux 7"]="oracle|7|https://yum.oracle.com/templates/OracleLinux/OL7/u7/x86_64/OL7U7_x86_64-kvm-b139.qcow2|oracle7|oracle|oracle"
    ["Oracle Linux 8"]="oracle|8|https://yum.oracle.com/templates/OracleLinux/OL8/u8/x86_64/OL8U8_x86_64-kvm-b283.qcow2|oracle8|oracle|oracle"
    ["Oracle Linux 9"]="oracle|9|https://yum.oracle.com/templates/OracleLinux/OL9/u1/x86_64/OL9U1_x86_64-kvm-b287.qcow2|oracle9|oracle|oracle"

    # Amazon Linux
    ["Amazon Linux 2023"]="amazon|2023|https://cdn.amazonlinux.com/al2023/releases/cloud/2023.0.20240219.0/x86_64/AmazonLinux2023-kvm-2023.0.20240219.0.x86_64.qcow2|amazon2023|ec2-user|ec2-user"
    ["Amazon Linux 2"]="amazon|2|https://cdn.amazonlinux.com/os-images/2.0.20240220.0/kvm/amzn2-kvm-2.0.20240220.0-x86_64.xfs.gpt.qcow2|amazon2|ec2-user|ec2-user"

    # FreeBSD
    ["FreeBSD 13.3"]="freebsd|13.3|https://download.freebsd.org/ftp/releases/VM-IMAGES/13.3-RELEASE/amd64/Latest/FreeBSD-13.3-RELEASE-amd64.qcow2.xz|freebsd13|root|freebsd"
    ["FreeBSD 14.1"]="freebsd|14.1|https://download.freebsd.org/ftp/releases/VM-IMAGES/14.1-RELEASE/amd64/Latest/FreeBSD-14.1-RELEASE-amd64.qcow2.xz|freebsd14|root|freebsd"

    # NetBSD
    ["NetBSD 10.0"]="netbsd|10.0|https://cdn.netbsd.org/pub/NetBSD/NetBSD-10.0/images/NetBSD-10.0-amd64.qcow2|netbsd10|root|netbsd"
    ["NetBSD 9.3"]="netbsd|9.3|https://cdn.netbsd.org/pub/NetBSD/NetBSD-9.3/images/NetBSD-9.3-amd64.qcow2|netbsd9|root|netbsd"

    # OpenBSD
    ["OpenBSD 7.4"]="openbsd|7.4|https://cdn.openbsd.org/pub/OpenBSD/7.4/amd64/openbsd-7.4-amd64.qcow2|openbsd74|root|openbsd"
    ["OpenBSD 7.5"]="openbsd|7.5|https://cdn.openbsd.org/pub/OpenBSD/7.5/amd64/openbsd-7.5-amd64.qcow2|openbsd75|root|openbsd"

    # DragonFly BSD
    ["DragonFly BSD 6.4"]="dragonfly|6.4|https://mirror-master.dragonflybsd.org/iso-images/dfly-x86_64-6.4.0_REL.img.gz|dragonfly64|root|dragonfly"

    # Container Linux (Flatcar)
    ["Flatcar Stable"]="flatcar|stable|https://stable.release.flatcar-linux.net/amd64-usr/current/flatcar_production_qemu_image.img.bz2|flatcar-stable|core|core"
    ["Flatcar Beta"]="flatcar|beta|https://beta.release.flatcar-linux.net/amd64-usr/current/flatcar_production_qemu_image.img.bz2|flatcar-beta|core|core"
    ["Flatcar Alpha"]="flatcar|alpha|https://alpha.release.flatcar-linux.net/amd64-usr/current/flatcar_production_qemu_image.img.bz2|flatcar-alpha|core|core"

    # RHEL Family (Requires subscription)
    ["RHEL 8.8"]="rhel|8.8|https://access.redhat.com/downloads/content/479/ver=/rhel---8/8.8/x86_64/product-software|rhel88|redhat|redhat"
    ["RHEL 9.2"]="rhel|9.2|https://access.redhat.com/downloads/content/480/ver=/rhel---9/9.2/x86_64/product-software|rhel92|redhat|redhat"

    # Scientific Linux (Discontinued but available)
    ["Scientific Linux 7"]="scientific|7|https://ftp.scientificlinux.org/linux/scientific/7.9/x86_64/images/SL-7.9-x86_64-GenericCloud.qcow2|scientific7|root|scientific"

    # Manjaro Linux
    ["Manjaro Linux"]="manjaro|latest|https://osdn.net/projects/manjaro/storage/kde/22.1.6/manjaro-kde-22.1.6-230616-linux61.iso|manjaro|manjaro|manjaro"

    # elementary OS
    ["elementary OS 7.1"]="elementary|7.1|https://github.com/elementary/os/releases/download/7.1-stable/elementaryos-7.1-stable.20231214.iso|elementary71|elementary|elementary"

    # Zorin OS
    ["Zorin OS 17"]="zorin|17|https://github.com/ZorinOS/zorin-os/releases/download/zorin-17/Zorin-OS-17-Core-64-bit.iso|zorin17|zorin|zorin"

    # Pop!_OS
    ["Pop!_OS 22.04 LTS"]="popos|22.04|https://iso.pop-os.org/22.04/amd64/intel/27/pop-os_22.04_amd64_intel_27.iso|popos22|pop|pop"

    # Mint Linux
    ["Linux Mint 21.3"]="mint|21.3|https://mirrors.edge.kernel.org/linuxmint/stable/21.3/linuxmint-21.3-cinnamon-64bit.iso|mint213|mint|mint"

    # Kali Linux
    ["Kali Linux 2024.2"]="kali|2024.2|https://cdimage.kali.org/kali-2024.2/kali-linux-2024.2-installer-amd64.iso|kali2024|kali|kali"

    # Parrot OS
    ["Parrot OS 6.0"]="parrot|6.0|https://deb.parrot.sh/parrot/iso/6.0/Parrot-security-6.0_amd64.iso|parrot60|parrot|parrot"

    # BlackArch Linux
    ["BlackArch Linux"]="blackarch|latest|https://mirror.rackspace.com/blackarch/iso/blackarch-linux-full-2024.09.01-x86_64.iso|blackarch|root|blackarch"

    # Tails
    ["Tails 6.0"]="tails|6.0|https://tails.net/install/vm/Tails_amd64-6.0.vdi|tails60|amnesia|amnesia"

    # Whonix
    ["Whonix Gateway 17"]="whonix|gateway17|https://download.whonix.org/linux/17/Whonix-Gateway-17.0.0.0.libvirt.xz|whonix-gateway|user|changeme"
    ["Whonix Workstation 17"]="whonix|workstation17|https://download.whonix.org/linux/17/Whonix-Workstation-17.0.0.0.libvirt.xz|whonix-workstation|user|changeme"

    # Qubes OS
    ["Qubes OS 4.2"]="qubes|4.2|https://mirrors.edge.kernel.org/qubes/iso/Qubes-R4.2.0-x86_64.iso|qubes42|user|qubes"

    # Trisquel
    ["Trisquel 11.0"]="trisquel|11.0|https://mirror.fsf.org/trisquel-images/trisquel_11.0_amd64.iso|trisquel11|trisquel|trisquel"

    # PureOS
    ["PureOS 10.0"]="pureos|10.0|https://cdn.puri.sm/pureos/amber/pureos-10.0-amd64.hybrid.iso|pureos10|pureos|pureos"

    # Devuan
    ["Devuan 5.0"]="devuan|5.0|https://files.devuan.org/devuan_daedalus/cloud/devuan_daedalus_5.0.0_amd64_qcow2.img.xz|devuan50|devuan|devuan"
    ["Devuan 4.0"]="devuan|4.0|https://files.devuan.org/devuan_chimaera/cloud/devuan_chimaera_4.0.0_amd64_qcow2.img.xz|devuan40|devuan|devuan"

    # Slackware
    ["Slackware 15.0"]="slackware|15.0|https://mirrors.slackware.com/slackware/slackware-iso/slackware64-15.0-iso/slackware64-15.0-install-dvd.iso|slackware15|root|slackware"

    # Tiny Core Linux
    ["Tiny Core Linux 15.0"]="tinycore|15.0|http://tinycorelinux.net/15.x/x86_64/release/TinyCorePure64-15.0.iso|tinycore15|tc|tc"

    # Puppy Linux
    ["Puppy Linux FossaPup64 9.5"]="puppy|fossapup64-9.5|http://distro.ibiblio.org/puppylinux/puppy-fossa/fossapup64-9.5.iso|puppy-fossapup|root|root"

    # Damn Small Linux
    ["Damn Small Linux 4.11"]="dsl|4.11|http://distro.ibiblio.org/damnsmall/current/dsl-4.11.rc2.iso|dsl411|root|root"

    # Porteus
    ["Porteus 5.0"]="porteus|5.0|https://download.porteus.org/x86_64/Porteus-KDE-v5.0-x86_64.iso|porteus5|guest|guest"

    # Slax
    ["Slax 15.0.1"]="slax|15.0.1|https://download.slax.org/slax-64bit-15.0.1.iso|slax15|root|toor"

    # Absolute Linux
    ["Absolute Linux 20240901"]="absolute|20240901|https://absolute-linux.org/downloads/absolute64-20240901.iso|absolute64|root|root"

    # Calculate Linux
    ["Calculate Linux 23"]="calculate|23|https://mirror.calculate-linux.org/calculate/23/calculate-linux-cld-23-x86_64.iso|calculate23|root|calculate"

    # Container-Optimized OS
    ["Container-Optimized OS (COS)"]="cos|stable|https://storage.googleapis.com/cos-tools/stable/cos-stable.img|cos-stable|chronos|chronos"
)

# ============================================================================
# End of OS List
# ============================================================================

# Start the main menu
main_menu
