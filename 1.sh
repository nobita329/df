#!/bin/bash
set -euo pipefail

# =============================
# Enhanced Multi-VM Manager with ISO Support
# =============================

# ... [Previous functions remain the same until the OS_OPTIONS declaration] ...

# Supported OS list - UPDATED WITH BOTH CLOUD IMAGES AND ISO INSTALLERS
declare -A OS_OPTIONS=(
    # Cloud Images
    ["Ubuntu 22.04 Cloud"]="ubuntu|jammy|https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img|CLOUD|ubuntu22|ubuntu|ubuntu"
    ["Ubuntu 24.04 Cloud"]="ubuntu|noble|https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img|CLOUD|ubuntu24|ubuntu|ubuntu"
    ["Debian 11 Cloud"]="debian|bullseye|https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2|CLOUD|debian11|debian|debian"
    ["Debian 12 Cloud"]="debian|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|CLOUD|debian12|debian|debian"
    ["Debian 13 Cloud"]="debian|trixie|https://cloud.debian.org/images/cloud/trixie/daily/latest/debian-13-generic-amd64-daily.qcow2|CLOUD|debian13|debian|debian"
    ["Fedora 40 Cloud"]="fedora|40|https://download.fedoraproject.org/pub/fedora/linux/releases/40/Cloud/x86_64/images/Fedora-Cloud-Base-40-1.14.x86_64.qcow2|CLOUD|fedora40|fedora|fedora"
    
    # ISO Installers
    ["Proxmox VE 9.1"]="proxmox|9.1|https://enterprise.proxmox.com/iso/proxmox-ve_9.1-1.iso|ISO|proxmox91|root|proxmox"
    ["Ubuntu 24.04 Desktop ISO"]="ubuntu|noble|https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso|ISO|ubuntu24-desktop|ubuntu|ubuntu"
    ["Debian 12 ISO"]="debian|bookworm|https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.5.0-amd64-netinst.iso|ISO|debian12-install|debian|debian"
    ["CentOS Stream 9 ISO"]="centos|stream9|https://download.cf.centos.org/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-latest-x86_64-dvd1.iso|ISO|centos9-install|root|centos"
)

# ... [Previous functions remain the same until setup_vm_image] ...

# Function to setup VM image - MODIFIED FOR BOTH CLOUD AND ISO
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
            exit 1
        fi
        mv "$IMG_FILE.tmp" "$IMG_FILE"
    fi
    
    # Handle different image types
    local IMAGE_TYPE=$(echo "$OS_OPTIONS" | grep "$OS_TYPE" | head -1 | cut -d'|' -f4)
    
    if [[ "$IMAGE_TYPE" == "CLOUD" ]]; then
        # Cloud image setup (original code)
        print_status "INFO" "☁️  Setting up cloud image..."
        
        # Resize the disk image if needed
        if ! qemu-img resize "$IMG_FILE" "$DISK_SIZE" 2>/dev/null; then
            print_status "WARN" "⚠️  Failed to resize disk image. Creating new image with specified size..."
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
        
        print_status "SUCCESS" "🎉 Cloud VM '$VM_NAME' created successfully."
        print_status "INFO" "🔑 Login with: username=$USERNAME, password=$PASSWORD"
        print_status "INFO" "🔌 SSH: ssh -p $SSH_PORT $USERNAME@localhost"
        
    elif [[ "$IMAGE_TYPE" == "ISO" ]]; then
        # ISO installer setup
        print_status "INFO" "📀 Setting up ISO installer..."
        
        # Create a blank disk image for installation
        if [[ ! -f "$IMG_FILE" ]] || [[ "$IMG_FILE" == *".iso" ]]; then
            # If IMG_FILE points to ISO, create a separate disk file
            ISO_FILE="$IMG_FILE"
            IMG_FILE="$VM_DIR/$VM_NAME-disk.img"
            # Update config to reflect this
            save_vm_config
        else
            ISO_FILE="$VM_DIR/$VM_NAME.iso"
            if [[ ! -f "$ISO_FILE" ]]; then
                cp "$IMG_FILE" "$ISO_FILE"
            fi
        fi
        
        # Create a fresh disk image
        qemu-img create -f qcow2 "$IMG_FILE" "$DISK_SIZE"
        
        # No seed file needed for ISO install
        SEED_FILE=""
        
        print_status "SUCCESS" "🎉 ISO-based VM '$VM_NAME' created successfully."
        print_status "INFO" "📀 You'll need to install the OS manually from the ISO"
        print_status "INFO" "🔑 Default credentials may vary (check OS documentation)"
    else
        print_status "ERROR" "❌ Unknown image type: $IMAGE_TYPE"
        exit 1
    fi
}

# Function to start a VM - MODIFIED FOR ISO SUPPORT
start_vm() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        # Determine image type
        local IMAGE_TYPE=""
        for os_option in "${!OS_OPTIONS[@]}"; do
            if [[ "$OS_TYPE" == "$(echo "$os_option" | cut -d' ' -f1)"* ]]; then
                IMAGE_TYPE=$(echo "${OS_OPTIONS[$os_option]}" | cut -d'|' -f4)
                break
            fi
        done
        
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
        
        if [[ "$IMAGE_TYPE" == "CLOUD" ]]; then
            print_status "INFO" "🔌 SSH: ssh -p $SSH_PORT $USERNAME@localhost"
            print_status "INFO" "🔑 Password: $PASSWORD"
        elif [[ "$IMAGE_TYPE" == "ISO" ]]; then
            print_status "INFO" "📀 Booting from ISO - manual installation required"
            print_status "INFO" "💡 After installation, you may need to adjust boot order"
        fi
        
        # Check if image file exists
        if [[ ! -f "$IMG_FILE" ]]; then
            print_status "ERROR" "❌ VM image file not found: $IMG_FILE"
            return 1
        fi
        
        # Base QEMU command
        local qemu_cmd=(
            qemu-system-x86_64
            -enable-kvm
            -m "$MEMORY"
            -smp "$CPUS"
            -cpu host
            -boot order=cd
        )
        
        # Add drives based on image type
        if [[ "$IMAGE_TYPE" == "CLOUD" ]]; then
            # Cloud image needs both disk and seed
            if [[ ! -f "$SEED_FILE" ]]; then
                print_status "WARN" "⚠️  Seed file not found, recreating..."
                setup_vm_image
            fi
            qemu_cmd+=(
                -drive "file=$IMG_FILE,format=qcow2,if=virtio"
                -drive "file=$SEED_FILE,format=raw,if=virtio"
            )
        elif [[ "$IMAGE_TYPE" == "ISO" ]]; then
            # ISO needs both ISO and disk
            local ISO_FILE="$VM_DIR/$vm_name.iso"
            if [[ ! -f "$ISO_FILE" ]] && [[ "$IMG_FILE" == *".iso" ]]; then
                ISO_FILE="$IMG_FILE"
                # Find the disk file
                IMG_FILE="$VM_DIR/$vm_name-disk.img"
                if [[ ! -f "$IMG_FILE" ]]; then
                    qemu-img create -f qcow2 "$IMG_FILE" "$DISK_SIZE"
                fi
            fi
            
            if [[ ! -f "$ISO_FILE" ]]; then
                print_status "ERROR" "❌ ISO file not found: $ISO_FILE"
                return 1
            fi
            
            qemu_cmd+=(
                -drive "file=$IMG_FILE,format=qcow2,if=virtio"
                -cdrom "$ISO_FILE"
            )
            
            # For ISO installs, we might want different default boot order
            qemu_cmd+=(-boot "menu=on")
        fi
        
        # Add networking
        qemu_cmd+=(
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

# ... [Rest of the functions remain the same] ...
