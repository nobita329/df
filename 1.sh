#!/bin/bash

# Simple LXC Manager
# Easy interface with normal container names

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Show menu
show_menu() {
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║        SIMPLE LXC MANAGER              ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════╝${NC}"
    echo -e "${CYAN}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}1.${NC} 📦 Create New Container"
    echo -e "  ${GREEN}2.${NC} 📋 List All Containers"
    echo -e "  ${GREEN}3.${NC} ▶️  Start Container"
    echo -e "  ${GREEN}4.${NC} ⏹️  Stop Container"
    echo -e "  ${GREEN}5.${NC} 🔄 Restart Container"
    echo -e "  ${GREEN}6.${NC} 🗑️  Delete Container"
    echo -e "  ${GREEN}7.${NC} 💻 Enter Container Shell"
    echo -e "  ${GREEN}8.${NC} 📊 Container Status"
    echo -e "  ${GREEN}9.${NC} ⚙️  Configure Container"
    echo -e "  ${GREEN}0.${NC} 🚪 Exit"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function 1: Create Container
create_container() {
    echo -e "\n${WHITE}📦 CREATE NEW CONTAINER${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Get container name
    read -p "$(echo -e "${YELLOW}Enter container name: ${NC}")" container_name
    
    if [[ -z "$container_name" ]]; then
        echo -e "${RED}Container name cannot be empty!${NC}"
        sleep 2
        return
    fi
    
    # Check if container exists
    if lxc list --format csv 2>/dev/null | grep -q "^$container_name,"; then
        echo -e "${RED}Container '$container_name' already exists!${NC}"
        sleep 2
        return
    fi
    
    # Show OS options
    echo -e "\n${CYAN}Select OS:${NC}"
    echo -e "  1. Ubuntu 22.04"
    echo -e "  2. Ubuntu 20.04"
    echo -e "  3. Debian 11"
    echo -e "  4. Debian 12"
    echo -e "  5. CentOS 7"
    echo -e "  6. Alpine Linux"
    
    read -p "$(echo -e "${YELLOW}Choose OS (1-6): ${NC}")" os_choice
    
    case $os_choice in
        1) os_image="ubuntu:22.04" ;;
        2) os_image="ubuntu:20.04" ;;
        3) os_image="debian:11" ;;
        4) os_image="debian:12" ;;
        5) os_image="centos:7" ;;
        6) os_image="alpine/edge" ;;
        *) os_image="ubuntu:22.04" ;;
    esac
    
    # Get resources
    echo -e "\n${CYAN}Container Resources:${NC}"
    read -p "$(echo -e "${YELLOW}CPU cores (default: 1): ${NC}")" cpu
    cpu=${cpu:-1}
    
    read -p "$(echo -e "${YELLOW}RAM in MB (default: 1024): ${NC}")" memory
    memory=${memory:-1024}
    
    read -p "$(echo -e "${YELLOW}Disk size in GB (default: 10): ${NC}")" disk
    disk=${disk:-10}
    
    # Create container
    echo -e "\n${CYAN}Creating container '$container_name'...${NC}"
    
    # Step 1: Launch container
    echo -e "${YELLOW}Step 1: Launching container...${NC}"
    if ! lxc launch "$os_image" "$container_name"; then
        echo -e "${RED}Failed to launch container!${NC}"
        echo -e "${YELLOW}Trying to fix storage...${NC}"
        
        # Try to fix storage
        lxc storage create default dir 2>/dev/null || true
        lxc profile device add default root disk path=/ pool=default 2>/dev/null || true
        
        # Try again
        if ! lxc launch "$os_image" "$container_name"; then
            echo -e "${RED}Still failed. Please check LXD installation.${NC}"
            sleep 2
            return
        fi
    fi
    
    # Step 2: Configure resources
    echo -e "${YELLOW}Step 2: Configuring resources...${NC}"
    lxc config set "$container_name" limits.cpu "$cpu"
    lxc config set "$container_name" limits.memory "${memory}MB"
    lxc config device override "$container_name" root size="${disk}GB"
    
    # Step 3: Enable common features
    echo -e "${YELLOW}Step 3: Enabling features...${NC}"
    lxc config set "$container_name" security.nesting true
    lxc config set "$container_name" security.privileged true
    
    echo -e "${GREEN}✅ Container '$container_name' created successfully!${NC}"
    
    # Show connection info
    echo -e "\n${CYAN}Connection Information:${NC}"
    echo -e "  SSH: ${YELLOW}lxc exec $container_name -- bash${NC}"
    echo -e "  Console: ${YELLOW}lxc console $container_name${NC}"
    
    # Get IP address
    sleep 3
    ip_address=$(lxc list "$container_name" --format csv | cut -d',' -f4 | xargs)
    if [[ -n "$ip_address" ]]; then
        echo -e "  IP Address: ${GREEN}$ip_address${NC}"
        echo -e "  SSH to IP: ${YELLOW}ssh ubuntu@$ip_address${NC}"
    fi
    
    read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
}

# Function 2: List Containers
list_containers() {
    echo -e "\n${WHITE}📋 ALL CONTAINERS${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Check if LXC is working
    if ! command -v lxc &> /dev/null; then
        echo -e "${RED}LXC is not installed!${NC}"
        echo -e "${YELLOW}Please install LXD first:${NC}"
        echo -e "  sudo snap install lxd"
        echo -e "  sudo lxd init --auto"
        read -p "$(echo -e "${YELLOW}Press Enter to continue...${NC}")"
        return
    fi
    
    # List containers with formatting
    echo -e "${CYAN}Container List:${NC}\n"
    
    if ! lxc list --format table; then
        echo -e "${YELLOW}No containers found or LXD not running.${NC}"
    fi
    
    # Show summary
    echo -e "\n${CYAN}Summary:${NC}"
    total=$(lxc list --format csv 2>/dev/null | wc -l)
    running=$(lxc list status=RUNNING --format csv 2>/dev/null | wc -l)
    stopped=$(lxc list status=STOPPED --format csv 2>/dev/null | wc -l)
    
    echo -e "  Total: $total | ${GREEN}Running: $running${NC} | ${RED}Stopped: $stopped${NC}"
    
    read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
}

# Function 3: Start Container
start_container() {
    echo -e "\n${WHITE}▶️ START CONTAINER${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Get stopped containers
    stopped_containers=$(lxc list status=STOPPED --format csv 2>/dev/null | cut -d',' -f1)
    
    if [[ -z "$stopped_containers" ]]; then
        echo -e "${YELLOW}No stopped containers found.${NC}"
        sleep 2
        return
    fi
    
    echo -e "${CYAN}Stopped Containers:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    i=1
    declare -A containers
    for container in $stopped_containers; do
        container=$(echo "$container" | xargs)
        containers[$i]=$container
        echo -e "  $i. $container"
        ((i++))
    done
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "$(echo -e "${YELLOW}Select container number: ${NC}")" choice
    
    if [[ -n "${containers[$choice]}" ]]; then
        container="${containers[$choice]}"
        echo -e "\n${CYAN}Starting $container...${NC}"
        lxc start "$container"
        
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}✅ Container started!${NC}"
        else
            echo -e "${RED}❌ Failed to start container${NC}"
        fi
    else
        echo -e "${RED}Invalid selection!${NC}"
    fi
    
    sleep 2
}

# Function 4: Stop Container
stop_container() {
    echo -e "\n${WHITE}⏹️ STOP CONTAINER${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Get running containers
    running_containers=$(lxc list status=RUNNING --format csv 2>/dev/null | cut -d',' -f1)
    
    if [[ -z "$running_containers" ]]; then
        echo -e "${YELLOW}No running containers found.${NC}"
        sleep 2
        return
    fi
    
    echo -e "${CYAN}Running Containers:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    i=1
    declare -A containers
    for container in $running_containers; do
        container=$(echo "$container" | xargs)
        containers[$i]=$container
        echo -e "  $i. $container"
        ((i++))
    done
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "$(echo -e "${YELLOW}Select container number: ${NC}")" choice
    
    if [[ -n "${containers[$choice]}" ]]; then
        container="${containers[$choice]}"
        
        # Ask for force stop
        read -p "$(echo -e "${YELLOW}Force stop? (y/N): ${NC}")" force_stop
        
        echo -e "\n${CYAN}Stopping $container...${NC}"
        
        if [[ "$force_stop" =~ ^[Yy]$ ]]; then
            lxc stop "$container" --force
        else
            lxc stop "$container"
        fi
        
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}✅ Container stopped!${NC}"
        else
            echo -e "${RED}❌ Failed to stop container${NC}"
        fi
    else
        echo -e "${RED}Invalid selection!${NC}"
    fi
    
    sleep 2
}

# Function 5: Restart Container
restart_container() {
    echo -e "\n${WHITE}🔄 RESTART CONTAINER${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Get all containers
    all_containers=$(lxc list --format csv 2>/dev/null | cut -d',' -f1)
    
    if [[ -z "$all_containers" ]]; then
        echo -e "${YELLOW}No containers found.${NC}"
        sleep 2
        return
    fi
    
    echo -e "${CYAN}All Containers:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    i=1
    declare -A containers
    for container in $all_containers; do
        container=$(echo "$container" | xargs)
        containers[$i]=$container
        status=$(lxc list "$container" --format csv | cut -d',' -f2 | xargs)
        echo -e "  $i. $container (${status^^})"
        ((i++))
    done
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "$(echo -e "${YELLOW}Select container number: ${NC}")" choice
    
    if [[ -n "${containers[$choice]}" ]]; then
        container="${containers[$choice]}"
        
        echo -e "\n${CYAN}Restarting $container...${NC}"
        lxc restart "$container"
        
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}✅ Container restarted!${NC}"
        else
            echo -e "${RED}❌ Failed to restart container${NC}"
        fi
    else
        echo -e "${RED}Invalid selection!${NC}"
    fi
    
    sleep 2
}

# Function 6: Delete Container
delete_container() {
    echo -e "\n${WHITE}🗑️ DELETE CONTAINER${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Get all containers
    all_containers=$(lxc list --format csv 2>/dev/null | cut -d',' -f1)
    
    if [[ -z "$all_containers" ]]; then
        echo -e "${YELLOW}No containers found.${NC}"
        sleep 2
        return
    fi
    
    echo -e "${CYAN}All Containers:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    i=1
    declare -A containers
    for container in $all_containers; do
        container=$(echo "$container" | xargs)
        containers[$i]=$container
        echo -e "  $i. $container"
        ((i++))
    done
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "$(echo -e "${YELLOW}Select container number: ${NC}")" choice
    
    if [[ -n "${containers[$choice]}" ]]; then
        container="${containers[$choice]}"
        
        # Warning
        echo -e "\n${RED}⚠️ WARNING: This will permanently delete '$container'${NC}"
        echo -e "${RED}All data will be lost!${NC}"
        
        read -p "$(echo -e "${YELLOW}Are you sure? (type 'yes' to confirm): ${NC}")" confirm
        
        if [[ "$confirm" == "yes" ]]; then
            read -p "$(echo -e "${YELLOW}Force delete? (y/N): ${NC}")" force_delete
            
            echo -e "\n${CYAN}Deleting $container...${NC}"
            
            if [[ "$force_delete" =~ ^[Yy]$ ]]; then
                lxc delete "$container" --force
            else
                lxc delete "$container"
            fi
            
            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}✅ Container deleted!${NC}"
            else
                echo -e "${RED}❌ Failed to delete container${NC}"
            fi
        else
            echo -e "${YELLOW}Deletion cancelled.${NC}"
        fi
    else
        echo -e "${RED}Invalid selection!${NC}"
    fi
    
    sleep 2
}

# Function 7: Enter Container Shell
enter_container() {
    echo -e "\n${WHITE}💻 ENTER CONTAINER SHELL${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Get running containers
    running_containers=$(lxc list status=RUNNING --format csv 2>/dev/null | cut -d',' -f1)
    
    if [[ -z "$running_containers" ]]; then
        echo -e "${YELLOW}No running containers found.${NC}"
        sleep 2
        return
    fi
    
    echo -e "${CYAN}Running Containers:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    i=1
    declare -A containers
    for container in $running_containers; do
        container=$(echo "$container" | xargs)
        containers[$i]=$container
        echo -e "  $i. $container"
        ((i++))
    done
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "$(echo -e "${YELLOW}Select container number: ${NC}")" choice
    
    if [[ -n "${containers[$choice]}" ]]; then
        container="${containers[$choice]}"
        
        echo -e "\n${CYAN}Entering $container shell...${NC}"
        echo -e "${YELLOW}Type 'exit' to return to menu${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # Enter container
        lxc exec "$container" -- /bin/bash
    else
        echo -e "${RED}Invalid selection!${NC}"
        sleep 2
    fi
}

# Function 8: Container Status
container_status() {
    echo -e "\n${WHITE}📊 CONTAINER STATUS${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Get all containers
    all_containers=$(lxc list --format csv 2>/dev/null | cut -d',' -f1)
    
    if [[ -z "$all_containers" ]]; then
        echo -e "${YELLOW}No containers found.${NC}"
        sleep 2
        return
    fi
    
    echo -e "${CYAN}Select Container:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    i=1
    declare -A containers
    for container in $all_containers; do
        container=$(echo "$container" | xargs)
        containers[$i]=$container
        echo -e "  $i. $container"
        ((i++))
    done
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "$(echo -e "${YELLOW}Select container number: ${NC}")" choice
    
    if [[ -n "${containers[$choice]}" ]]; then
        container="${containers[$choice]}"
        
        echo -e "\n${CYAN}Status for: $container${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # Show detailed info
        lxc info "$container"
        
        # Show IP address
        ip=$(lxc list "$container" --format csv | cut -d',' -f4 | xargs)
        echo -e "\n${CYAN}IP Address:${NC} $ip"
        
        # Show resource usage
        echo -e "\n${CYAN}Resource Limits:${NC}"
        lxc config show "$container" | grep -E "(limits\.cpu|limits\.memory|root\.size)"
        
    else
        echo -e "${RED}Invalid selection!${NC}"
    fi
    
    read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
}

# Function 9: Configure Container
configure_container() {
    echo -e "\n${WHITE}⚙️ CONFIGURE CONTAINER${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Get all containers
    all_containers=$(lxc list --format csv 2>/dev/null | cut -d',' -f1)
    
    if [[ -z "$all_containers" ]]; then
        echo -e "${YELLOW}No containers found.${NC}"
        sleep 2
        return
    fi
    
    echo -e "${CYAN}Select Container:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    i=1
    declare -A containers
    for container in $all_containers; do
        container=$(echo "$container" | xargs)
        containers[$i]=$container
        echo -e "  $i. $container"
        ((i++))
    done
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "$(echo -e "${YELLOW}Select container number: ${NC}")" choice
    
    if [[ -n "${containers[$choice]}" ]]; then
        container="${containers[$choice]}"
        
        echo -e "\n${CYAN}Configure: $container${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        echo -e "  1. Change CPU cores"
        echo -e "  2. Change RAM"
        echo -e "  3. Change Disk size"
        echo -e "  4. Enable/Disable features"
        echo -e "  5. View current config"
        
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        read -p "$(echo -e "${YELLOW}Select option: ${NC}")" config_choice
        
        case $config_choice in
            1)
                read -p "$(echo -e "${YELLOW}New CPU cores: ${NC}")" new_cpu
                lxc config set "$container" limits.cpu "$new_cpu"
                echo -e "${GREEN}✅ CPU updated!${NC}"
                ;;
            2)
                read -p "$(echo -e "${YELLOW}New RAM (MB): ${NC}")" new_ram
                lxc config set "$container" limits.memory "${new_ram}MB"
                echo -e "${GREEN}✅ RAM updated!${NC}"
                ;;
            3)
                read -p "$(echo -e "${YELLOW}New Disk size (GB): ${NC}")" new_disk
                lxc config device override "$container" root size="${new_disk}GB"
                echo -e "${GREEN}✅ Disk updated!${NC}"
                ;;
            4)
                echo -e "\n${CYAN}Features:${NC}"
                echo -e "  1. Enable nesting"
                echo -e "  2. Disable nesting"
                echo -e "  3. Enable privileged"
                echo -e "  4. Disable privileged"
                read -p "$(echo -e "${YELLOW}Select: ${NC}")" feature_choice
                
                case $feature_choice in
                    1) lxc config set "$container" security.nesting true
                       echo -e "${GREEN}✅ Nesting enabled!${NC}" ;;
                    2) lxc config set "$container" security.nesting false
                       echo -e "${GREEN}✅ Nesting disabled!${NC}" ;;
                    3) lxc config set "$container" security.privileged true
                       echo -e "${GREEN}✅ Privileged mode enabled!${NC}" ;;
                    4) lxc config set "$container" security.privileged false
                       echo -e "${GREEN}✅ Privileged mode disabled!${NC}" ;;
                    *) echo -e "${RED}Invalid option!${NC}" ;;
                esac
                ;;
            5)
                echo -e "\n${CYAN}Current configuration:${NC}"
                lxc config show "$container"
                ;;
            *)
                echo -e "${RED}Invalid option!${NC}"
                ;;
        esac
        
    else
        echo -e "${RED}Invalid selection!${NC}"
    fi
    
    read -p "$(echo -e "\n${YELLOW}Press Enter to continue...${NC}")"
}

# Main loop
while true; do
    show_menu
    read -p "$(echo -e "${YELLOW}Select option [0-9]: ${NC}")" choice
    
    case $choice in
        1) create_container ;;
        2) list_containers ;;
        3) start_container ;;
        4) stop_container ;;
        5) restart_container ;;
        6) delete_container ;;
        7) enter_container ;;
        8) container_status ;;
        9) configure_container ;;
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
