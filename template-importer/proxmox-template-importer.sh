#!/bin/bash
# Proxmox Cloud-Init Template Import Script
# Automates downloading a cloud image, optionally customizing it with basic packages,
# and importing it as a VM template into Proxmox.
#
# DISCLAIMER: Installing libguestfs-tools (which provides virt-customize) on production systems is not advised.


# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

# Global variable to track if virt-customize is available
VIRT_CUSTOMIZE_AVAILABLE=false
# Global flag if the selected image is RedHat-based
REDHAT_BASED=false
# Global flag for EFI enablement
ENABLE_EFI=false
# Global variable for disk format
DISK_FORMAT="qcow2"

#######################################
# Extract compressed files based on their extension
# Arguments:
#   $1 - Path to compressed file
#   $2 - Target directory
# Returns:
#   Path to the extracted image file
#######################################
extract_compressed_file() {
    local compressed_file="$1"
    local target_dir="$2"
    local extracted_file=""

    case "$compressed_file" in
        *.tar.xz)
            echo -e "${BLUE}Extracting tar.xz file...${NC}"
            tar -xf "$compressed_file" -C "$target_dir"
            # For Kali cloud image, we know it extracts to disk.raw
            if [[ "$compressed_file" == *"kali-linux"*"cloud-genericcloud"* ]]; then
                extracted_file="${target_dir}/disk.raw"
                DISK_FORMAT="raw"
            fi
            ;;
        *.7z)
            echo -e "${BLUE}Extracting 7z file...${NC}"
            if ! command -v 7z &> /dev/null; then
                echo -e "${YELLOW}7z not found. Installing p7zip-full...${NC}"
                apt-get update && apt-get install -y p7zip-full
            fi
            7z x "$compressed_file" -o"$target_dir"
            # For Kali desktop image, we know it extracts to .qcow2
            if [[ "$compressed_file" == *"kali-linux"*"qemu"* ]]; then
                extracted_file="${target_dir}/kali-linux-"*"-qemu-amd64.qcow2"
                DISK_FORMAT="qcow2"
            fi
            ;;
        *)
            # Not a compressed file, set format based on extension
            if [[ "$compressed_file" == *.raw ]]; then
                DISK_FORMAT="raw"
            else
                DISK_FORMAT="qcow2"
            fi
            extracted_file="$compressed_file"
            ;;
    esac

    # If we found an extracted file, update CLOUD_IMAGE_PATH
    if [[ -n "$extracted_file" && -f "$extracted_file" ]]; then
        echo -e "${GREEN}Extracted file: $extracted_file (Format: $DISK_FORMAT)${NC}"
        CLOUD_IMAGE_PATH="$extracted_file"
    else
        echo -e "${RED}Failed to extract or find the image file${NC}"
        exit 1
    fi
}

#######################################
# Global array of cloud images.
# Format: "Display Name|Download URL|Filename"
# (The images will be sorted alphabetically by Display Name.)
#######################################
IMAGES=(
    "AlmaLinux 8|https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2|AlmaLinux-8-GenericCloud-latest.x86_64.qcow2"
    "AlmaLinux 9|https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2|AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
    "Debian 10 Buster|https://cloud.debian.org/images/cloud/buster/latest/debian-10-genericcloud-amd64.qcow2|debian-10-genericcloud-amd64.qcow2"
    "Debian 11 Bullseye|https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-genericcloud-amd64.qcow2|debian-11-genericcloud-amd64.qcow2"
    "Debian 11 Bullseye (Backports)|https://cloud.debian.org/images/cloud/bullseye-backports/latest/debian-11-backports-genericcloud-amd64.qcow2|debian-11-backports-genericcloud-amd64.qcow2"
    "Debian 12 Bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|debian-12-generic-amd64.qcow2"
    "Fedora 38|https://ftp.riken.jp/Linux/fedora/releases/38/Cloud/x86_64/images/Fedora-Cloud-Base-38-1.6.x86_64.qcow2|Fedora-Cloud-Base-38-1.6.x86_64.qcow2"
    "Kali Linux 2024.4 Cloud|https://kali.download/cloud-images/current/kali-linux-2024.4-cloud-genericcloud-amd64.tar.xz|kali-linux-2024.4-cloud-genericcloud-amd64.tar.xz"
    "Kali Linux 2024.4 Desktop|https://cdimage.kali.org/kali-2024.4/kali-linux-2024.4-qemu-amd64.7z|kali-linux-2024.4-qemu-amd64.7z"
    "Rocky Linux 8|https://dl.rockylinux.org/pub/rocky/8/images/x86_64/Rocky-8-GenericCloud-Base.latest.x86_64.qcow2|Rocky-8-GenericCloud-Base.latest.x86_64.qcow2"
    "Rocky Linux 9|https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2|Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
    "Ubuntu 18.04 LTS Bionic Beaver|https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img|bionic-server-cloudimg-amd64.img"
    "Ubuntu 20.04 LTS Focal Fossa|https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img|focal-server-cloudimg-amd64.img"
    "Ubuntu 24.04 LTS Noble Numbat|https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img|noble-server-cloudimg-amd64.img"
)

#######################################
# Sort the IMAGES array alphabetically by Display Name.
#######################################
sort_images() {
    IFS=$'\n' sorted=($(printf "%s\n" "${IMAGES[@]}" | sort))
    unset IFS
    IMAGES=("${sorted[@]}")
}

#######################################
# Check if virt-customize is installed.
# If not, prompt the user to install it.
#######################################
check_virt_customize() {
    if ! command -v virt-customize >/dev/null 2>&1; then
        echo -e "${YELLOW}virt-customize is not installed.${NC}"
        echo -e "${YELLOW}DISCLAIMER: Installing libguestfs-tools on production systems is not advised.${NC}"
        read -p "Do you want to install virt-customize (libguestfs-tools)? [y/N]: " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            sudo apt-get update && sudo apt-get install -y libguestfs-tools
            if command -v virt-customize >/dev/null 2>&1; then
                VIRT_CUSTOMIZE_AVAILABLE=true
                echo -e "${GREEN}virt-customize successfully installed.${NC}"
            else
                echo -e "${RED}Installation failed. Continuing without image customization support.${NC}"
            fi
        else
            echo -e "${RED}Skipping virt-customize installation. Image customization will be skipped.${NC}"
        fi
    else
        VIRT_CUSTOMIZE_AVAILABLE=true
        echo -e "${GREEN}virt-customize is installed.${NC}"
    fi
}

#######################################
# Present a menu for selecting a cloud image template.
# Sets: SELECTED_IMAGE_NAME, CLOUD_TEMPLATE_URL, and CLOUD_IMAGE_FILENAME.
# Also determines if the image is RedHat-based.
#######################################
choose_template() {
    sort_images
    echo -e "${BLUE}Select a cloud image template to download:${NC}"
    local i=1
    for entry in "${IMAGES[@]}"; do
        IFS="|" read -r name url filename <<< "$entry"
        echo "  $i) $name"
        ((i++))
    done
    read -p "Enter choice [1-${#IMAGES[@]}]: " choice
    if [[ "$choice" -lt 1 || "$choice" -gt ${#IMAGES[@]} ]]; then
        echo -e "${RED}Invalid option. Exiting.${NC}"
        exit 1
    fi
    IFS="|" read -r SELECTED_IMAGE_NAME CLOUD_TEMPLATE_URL CLOUD_IMAGE_FILENAME <<< "${IMAGES[$((choice-1))]}"
    echo -e "${GREEN}Selected: $SELECTED_IMAGE_NAME${NC}"
    # Detect if the image is RedHat-based
    if [[ "$SELECTED_IMAGE_NAME" =~ (Rocky|AlmaLinux|Fedora|CentOS|RHEL) ]]; then
        REDHAT_BASED=true
    else
        REDHAT_BASED=false
    fi
}

#######################################
# Download the selected cloud image into a temporary directory.
# Uses quiet mode with a progress bar.
# Sets: CLOUD_IMAGE_PATH.
#######################################
download_image() {
    TMP_DIR=$(mktemp -d)
    echo -e "${BLUE}Downloading ${CLOUD_IMAGE_FILENAME} into temporary directory ${TMP_DIR}...${NC}"
    wget -q --show-progress -O "${TMP_DIR}/${CLOUD_IMAGE_FILENAME}" "${CLOUD_TEMPLATE_URL}"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Download failed. Exiting.${NC}"
        exit 1
    fi
    CLOUD_IMAGE_PATH="${TMP_DIR}/${CLOUD_IMAGE_FILENAME}"
    echo -e "${GREEN}Download completed: ${CLOUD_IMAGE_PATH}${NC}"

    # Handle compressed files
    if [[ "$CLOUD_IMAGE_FILENAME" =~ \.(tar\.xz|7z)$ ]]; then
        extract_compressed_file "$CLOUD_IMAGE_PATH" "$TMP_DIR"
    fi
}

#######################################
# Optionally customize the downloaded image with basic packages.
# Uses different package lists for Debian/Ubuntu vs RedHat-based images.
#######################################
prompt_basic_packages() {
    if [ "$VIRT_CUSTOMIZE_AVAILABLE" = true ]; then
        if [ "$REDHAT_BASED" = true ]; then
            PACKAGES="qemu-guest-agent,lnav,ca-certificates,net-tools,bind-utils"
        else
            PACKAGES="qemu-guest-agent,lnav,ca-certificates,apt-transport-https,net-tools,dnsutils"
        fi
        read -p "Do you want to install basic packages (${PACKAGES}) into the image? [y/N]: " install_packages_choice
        if [[ "$install_packages_choice" =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}Customizing image with basic packages...${NC}"
            sudo virt-customize -a "${CLOUD_IMAGE_PATH}" --install "$PACKAGES"
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Image customized successfully.${NC}"
            else
                echo -e "${RED}Image customization failed.${NC}"
            fi
        else
            echo -e "${YELLOW}Skipping image customization.${NC}"
        fi
    else
        echo -e "${YELLOW}virt-customize not available. Skipping image customization.${NC}"
    fi
}

#######################################
# Dynamically select a storage that supports VM images.
# Uses: pvesm status --content images.
#######################################
select_storage() {
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}Select a storage for the template disk image:${NC}"
    echo -e "${BLUE}The list below shows storages (via 'pvesm status --content images') that support VM images.${NC}"
    echo -e "${BLUE}==========================================${NC}"

    if command -v pvesm >/dev/null 2>&1; then
        AVAILABLE_STORAGES=($(pvesm status --content images | awk 'NR>1 {print $1}'))
        if [ ${#AVAILABLE_STORAGES[@]} -eq 0 ]; then
            echo -e "${RED}No storages found via pvesm supporting VM images. Please enter storage manually.${NC}"
            read -p "Enter STORAGE (e.g., nvme-2tb): " STORAGE
            STORAGE=${STORAGE:-nvme-2tb}
        else
            local i=1
            for storage in "${AVAILABLE_STORAGES[@]}"; do
                echo "  $i) $storage"
                ((i++))
            done
            read -p "Enter your choice [1-${#AVAILABLE_STORAGES[@]}]: " storage_choice
            if [[ $storage_choice -ge 1 && $storage_choice -le ${#AVAILABLE_STORAGES[@]} ]]; then
                STORAGE="${AVAILABLE_STORAGES[$((storage_choice-1))]}"
                echo -e "${GREEN}Selected storage: ${STORAGE}${NC}"
            else
                echo -e "${RED}Invalid selection. Using default storage 'nvme-2tb'.${NC}"
                STORAGE="nvme-2tb"
            fi
        fi
    else
        echo -e "${YELLOW}pvesm command not found. Please enter storage manually.${NC}"
        read -p "Enter STORAGE (e.g., nvme-2tb): " STORAGE
        STORAGE=${STORAGE:-nvme-2tb}
    fi
}

#######################################
# Check if a given VM ID is already taken.
# Returns 0 (true) if taken.
#######################################
check_vm_id_taken() {
    if qm list | awk 'NR>1 {print $1}' | grep -q "^$1$"; then
        return 0
    else
        return 1
    fi
}

#######################################
# Prompt for Cloud-Init template settings together.
# Order: TEMPLATE NAME, VM TEMPLATE ID, VM USER, VM PASSWORD, DNS1, DNS2, DNS SEARCH DOMAIN, and EFI enablement.
# Suggests a default template name based on the selected image.
# The default VM ID is the next available (via pvesh) and is checked against existing IDs.
#######################################
get_cloud_init_inputs() {
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}Cloud-Init Template Settings${NC}"
    echo -e "${BLUE}==========================================${NC}"
    # Suggest a default template name based on the selected image name.
    default_template=$(echo "$SELECTED_IMAGE_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g')-template
    read -p "Enter TEMPLATE NAME (default: ${default_template}): " TEMPLATE_NAME
    TEMPLATE_NAME=${TEMPLATE_NAME:-$default_template}

    # Get the next available VM ID (if pvesh is available)
    default_vm_id=$(pvesh get /cluster/nextid 2>/dev/null)
    if [ -z "$default_vm_id" ]; then
        default_vm_id=100
    fi
    while true; do
        read -p "Enter VM TEMPLATE ID (default: ${default_vm_id}): " VM_TEMPLATE_ID
        VM_TEMPLATE_ID=${VM_TEMPLATE_ID:-$default_vm_id}
        if check_vm_id_taken "$VM_TEMPLATE_ID"; then
            echo -e "${RED}VM ID ${VM_TEMPLATE_ID} is already taken. Please choose another.${NC}"
        else
            break
        fi
    done

    read -p "Enter VM USER (e.g., karubits): " VM_USER
    VM_USER=${VM_USER:-karubits}
    read -rs -p "Enter VM Password: " VM_PASSWORD; echo ""
    read -p "Enter DNS1 [1.1.1.1]: " DNS1; DNS1=${DNS1:-1.1.1.1}
    read -p "Enter DNS2 [8.8.8.8]: " DNS2; DNS2=${DNS2:-8.8.8.8}
    read -p "Enter DNS Search Domain [karubits.com]: " DNSSEARCH; DNSSEARCH=${DNSSEARCH:-karubits.com}
    read -p "Enable EFI? [y/N]: " efi_choice
    if [[ "$efi_choice" =~ ^[Yy]$ ]]; then
        ENABLE_EFI=true
    else
        ENABLE_EFI=false
    fi
    echo -e "${BLUE}Using VM ID ${VM_TEMPLATE_ID} (next available by default is ${default_vm_id}).${NC}"
}

#######################################
# Import the downloaded (and optionally customized) image as a Proxmox VM template.
# The verbose output from qm importdisk is suppressed.
#######################################
import_vm() {
    echo -e "${BLUE}Creating VM template with ID ${VM_TEMPLATE_ID} and name ${TEMPLATE_NAME}...${NC}"
    # Build the create command with EFI option if enabled
    CREATE_CMD=(qm create ${VM_TEMPLATE_ID} \
        --name "${TEMPLATE_NAME}" \
        --cores 2 \
        --memory 2048 \
        --net0 virtio,bridge=vmbr0 \
        --ide2 "${STORAGE}:cloudinit" \
        --serial0 socket \
        --vga serial0 \
        --onboot 1 \
        --agent 1,fstrim_cloned_disks=1 \
        --tablet 0 \
        --ostype l26)
    if [ "$ENABLE_EFI" = true ]; then
        CREATE_CMD+=(--bios ovmf)
    fi
    "${CREATE_CMD[@]}"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to create VM template. Exiting.${NC}"
        exit 1
    fi

    echo -e "${BLUE}Importing disk image into VM template...${NC}"
    if qm importdisk ${VM_TEMPLATE_ID} "${CLOUD_IMAGE_PATH}" ${STORAGE} --format ${DISK_FORMAT} > /dev/null 2>&1; then
        echo -e "${GREEN}Disk image imported successfully.${NC}"
    else
        echo -e "${RED}Disk import failed. Exiting.${NC}"
        exit 1
    fi

    echo -e "${BLUE}Attaching disk to VM template...${NC}"
    # Wait a moment for the import to complete and the disk to be available
    sleep 2
    qm set ${VM_TEMPLATE_ID} \
        --scsihw virtio-scsi-pci \
        --scsi0 "${STORAGE}:vm-${VM_TEMPLATE_ID}-disk-0,discard=on,ssd=1" \
        --boot c \
        --bootdisk scsi0

    echo -e "${BLUE}Configuring cloud-init settings for the template...${NC}"
    qm set ${VM_TEMPLATE_ID} \
        --nameserver="${DNS1} ${DNS2}" \
        --searchdomain="${DNSSEARCH}" \
        --ipconfig0=ip=dhcp \
        --ciuser="${VM_USER}" \
        --cipassword="${VM_PASSWORD}"

    echo -e "${BLUE}Converting VM to template...${NC}"
    if qm template ${VM_TEMPLATE_ID} > /dev/null 2>&1; then
        echo -e "${GREEN}VM template created successfully.${NC}"
    else
        echo -e "${RED}Failed to convert VM to template.${NC}"
    fi
}

#######################################
# Main function orchestrating the script workflow.
#######################################
main() {
    echo -e "${BLUE}Starting Proxmox Cloud-Init Template Import Script...${NC}"
    check_virt_customize
    choose_template
    download_image
    if [ "$VIRT_CUSTOMIZE_AVAILABLE" = true ]; then
        prompt_basic_packages
    fi
    select_storage
    get_cloud_init_inputs
    import_vm
    echo -e "${GREEN}All done! Your VM template has been created.${NC}"
}

# Execute main function
main
