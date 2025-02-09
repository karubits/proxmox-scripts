#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to get IP addresses for a VM
get_vm_ips() {
    local VMID=$1
    # Check if VM exists and is running
    if ! qm status $VMID >/dev/null 2>&1; then
        printf "${RED}VM not found${NC}"
        return 1
    fi
    
    if [ "$(qm status $VMID)" != "status: running" ]; then
        printf "${YELLOW}Not Running${NC}"
        return 1
    fi

    # Get IP addresses, filter out loopback and IPv6, and format as comma-separated
    local ip_data
    ip_data=$(qm guest cmd $VMID network-get-interfaces 2>/dev/null)
    if [ $? -ne 0 ]; then
        printf "${YELLOW}No IP Data${NC}"
        return 1
    fi
    
    echo "$ip_data" | jq -r '
        [.[] | 
        select(.["ip-addresses"] != null) | 
        .["ip-addresses"][] | 
        select(.["ip-address-type"] == "ipv4" and .["ip-address"] != "127.0.0.1") | 
        .["ip-address"]] | 
        join(", ")' 2>/dev/null || printf "${YELLOW}No IP Data${NC}"
}

# Function to get VM name
get_vm_name() {
    local VMID=$1
    local name
    name=$(qm config $VMID 2>/dev/null | grep '^name: ' | cut -d' ' -f2)
    if [ -n "$name" ]; then
        printf "%-20s" "$name"
    else
        printf "${RED}%-20s${NC}" "Not Found"
    fi
}

# Print header
printf "${BLUE}%-6s %-20s %-15s${NC}\n" "VM ID" "VM NAME" "IP ADDRESSES"
printf "${BLUE}%-41s${NC}\n" "----------------------------------------"

# Get running VMs dynamically
mapfile -t VMS < <(qm list | grep running | awk '{print $1}')

# Get data for each VM
for VMID in "${VMS[@]}"; do
    VM_NAME=$(get_vm_name $VMID)
    
    IP_ADDRESSES=$(get_vm_ips $VMID)
    if [ -z "$IP_ADDRESSES" ]; then
        IP_ADDRESSES="${YELLOW}Not Available${NC}"
    fi
    
    printf "${GREEN}%-6s${NC} ${YELLOW}%s${NC} ${BLUE}%-39s${NC}\n" \
        "$VMID" "$VM_NAME" "$IP_ADDRESSES"
done

# Print footer
printf "${BLUE}%-41s${NC}\n" "----------------------------------------" 