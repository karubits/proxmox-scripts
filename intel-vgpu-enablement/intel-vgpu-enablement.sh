    #!/bin/bash
    # Script Name: Enable Intel vGPU on Proxmox
    # Description: Enables Intel GPU virtualization (vGPU) on Proxmox by configuring SR-IOV
    # on the integrated Intel GPU. This is done by installing the i915-sriov-dkms module,
    # updating GRUB configuration, and configuring the system for GPU virtualization.
    # It includes error handling and colorful status messages.
    #
    # References:
    #  - SpaceTerran's guide on iGPU/vGPU passthrough:
    #      https://spaceterran.com/posts/igpu-vgpu-passthrough-on-ms-01-proxmox-ubuntu-plex-docker-transcoding/
    #  - i915-sriov-dkms GitHub repository:
    #      https://github.com/strongtz/i915-sriov-dkms

    # Define color variables
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'  # No Color

    # Function to print a separator line
    print_separator() {
        echo -e "${BLUE}------------------------------------------------${NC}"
    }

    # Function to check if a command exists
    command_exists() {
        command -v "$1" >/dev/null 2>&1
    }

    # Function to check and install required packages
    check_and_install_dependencies() {
        echo -e "${BLUE}Checking and installing required packages...${NC}"
        
        # Define all required packages
        local REQUIRED_PACKAGES="sysfsutils pve-headers mokutil build-essential dkms curl jq"
        local MISSING_PACKAGES=""

        # Check which packages are missing
        for package in $REQUIRED_PACKAGES; do
            if ! dpkg -s "$package" &>/dev/null; then
                if [ -z "$MISSING_PACKAGES" ]; then
                    MISSING_PACKAGES="$package"
                else
                    MISSING_PACKAGES="$MISSING_PACKAGES $package"
                fi
            fi
        done

        # Install missing packages if any
        if [ -n "$MISSING_PACKAGES" ]; then
            echo -e "${YELLOW}Installing missing packages: $MISSING_PACKAGES${NC}"
            apt update || error_exit "apt update failed."
            apt install -y $MISSING_PACKAGES || error_exit "Failed to install required packages."
            echo -e "${GREEN}Successfully installed all required packages.${NC}"
        else
            echo -e "${GREEN}All required packages are already installed.${NC}"
        fi
        print_separator
    }

    # Function to get the latest release version and URL
    get_latest_release() {
        local api_url="https://api.github.com/repos/strongtz/i915-sriov-dkms/releases/latest"
        local latest_version
        local deb_url

        echo -e "${BLUE}Checking for latest release...${NC}"
        
        # Get the latest release information
        local release_info
        release_info=$(curl -s "$api_url")
        
        # Extract version and .deb asset URL
        latest_version=$(echo "$release_info" | jq -r .tag_name)
        deb_url=$(echo "$release_info" | jq -r '.assets[] | select(.name | endswith(".deb")) | .browser_download_url')

        if [ -z "$latest_version" ] || [ -z "$deb_url" ]; then
            error_exit "Could not fetch latest release information"
        fi

        echo -e "${GREEN}Latest version: $latest_version${NC}"
        echo -e "${GREEN}Downloading from: $deb_url${NC}"
        print_separator

        # Download the .deb package
        local deb_file="/tmp/i915-sriov-dkms.deb"
        echo -e "${BLUE}Downloading package...${NC}"
        if ! curl -L -o "$deb_file" "$deb_url"; then
            error_exit "Failed to download .deb package"
        fi
        echo -e "${GREEN}Download complete${NC}"
        print_separator

        # Install the package
        echo -e "${BLUE}Installing i915-sriov-dkms package...${NC}"
        if ! dpkg -i "$deb_file"; then
            echo -e "${YELLOW}Warning: Installation failed. Attempting to fix dependencies...${NC}"
            apt-get install -f -y
            if ! dpkg -i "$deb_file"; then
                error_exit "Installation failed"
            fi
        fi
        echo -e "${GREEN}Successfully installed i915-sriov-dkms package${NC}"
        print_separator

        # Clean up
        echo -e "${BLUE}Cleaning up temporary files...${NC}"
        rm -f "$deb_file"
        echo -e "${GREEN}Cleanup complete${NC}"
        print_separator
    }

    # Main script execution
    if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be run as root"
        exit 1
    fi

    # Check for Intel GPU presence
    echo -e "${BLUE}Checking for Intel GPU {💻}...${NC}"
    if ! lspci | grep -i 'vga' | grep -i 'intel' > /dev/null; then
        error_exit "Intel GPU not detected. Exiting."
    fi
    echo -e "${GREEN}Intel GPU detected.${NC}"
    print_separator

    # Display a title banner
    echo -e "${YELLOW}=============================================="
    echo -e "       Intel GPU Virtualization Enabler"
    echo -e "==============================================${NC}"
    print_separator

    # Explanation prompt with the steps
    echo -e "${YELLOW}This script will perform the following steps:${NC}"
    echo -e "${YELLOW}  1. Install required dependencies {🔧}"
    echo -e "  2. Download and install i915-sriov-dkms for GPU virtualization {📦}"
    echo -e "  3. Update GRUB configuration for vGPU support"
    echo -e "  4. Configure sysfs for virtual GPU functions"
    echo -e "  5. Update initramfs and prompt for a system reboot${NC}"
    print_separator

    echo -ne "${YELLOW}Do you want to continue? (y/n): ${NC}"
    read -r answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        echo -e "\n${YELLOW}Operation cancelled by user. Exiting.${NC}\n"
        exit 0
    fi
    print_separator

    # Check and install required packages
    check_and_install_dependencies

    # Get and install latest release
    get_latest_release


    # Display DKMS status
    echo -e "${BLUE}Displaying DKMS status...${NC}"
    dkms status || error_exit "DKMS status command failed."
    print_separator

    # Backup GRUB configuration
    echo -e "${BLUE}Backing up GRUB configuration {⚙️}...${NC}"
    TIMESTAMP=$(date +%y%m%d-%H%M)
    cp -a /etc/default/grub{,."$TIMESTAMP".bak} || error_exit "Failed to backup GRUB configuration."
    print_separator

    # Update GRUB configuration to enable Intel iGPU
    echo -e "${BLUE}Updating GRUB configuration to enable Intel iGPU...${NC}"
    echo -e "${GREEN}Note: xe driver will be blacklisted for Linux VM support${NC}"
    echo -e "  - It will NOT affect the physical GPU's display output"
    echo -e "  - The physical GPU will continue working with the i915 driver\n"
    GRUB_PARAMS="quiet intel_iommu=on i915.enable_guc=3 i915.max_vfs=7 module_blacklist=xe"

    if grep -q "^GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_PARAMS\"" /etc/default/grub; then
        echo -e "${GREEN}GRUB configuration already contains required settings. Skipping...${NC}"
    else
        sed -i "/^GRUB_CMDLINE_LINUX_DEFAULT/c\GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_PARAMS\"" /etc/default/grub || error_exit "Failed to update GRUB configuration."
    fi
    print_separator

    # Update GRUB and initramfs
    echo -e "${BLUE}Updating GRUB...${NC}"
    update-grub || error_exit "Failed to update GRUB."
    print_separator

    echo -e "${BLUE}Updating initramfs {🖥️}...${NC}"
    update-initramfs -u -k all || error_exit "Failed to update initramfs."
    print_separator

    # Configure sysfs for vGPU
    echo -e "${BLUE}Configuring sysfs for vGPU...${NC}"
    # Backup existing sysfs.conf if it exists
    if [ -f /etc/sysfs.conf ]; then
        cp /etc/sysfs.conf "/etc/sysfs.conf.${TIMESTAMP}.bak" || error_exit "Failed to backup sysfs.conf"
        
        # Check if the configuration line already exists
        if grep -q "devices/pci0000:00/0000:00:02.0/sriov_numvfs = 7" /etc/sysfs.conf; then
            echo -e "${GREEN}vGPU configuration already exists in sysfs.conf. Skipping...${NC}"
        else
            # Add vGPU configuration to sysfs.conf
            echo "devices/pci0000:00/0000:00:02.0/sriov_numvfs = 7" | tee -a /etc/sysfs.conf > /dev/null || error_exit "Failed to update sysfs.conf"
            echo -e "${GREEN}Successfully configured sysfs for vGPU${NC}"
        fi
    else
        # Add vGPU configuration to sysfs.conf
        echo "devices/pci0000:00/0000:00:02.0/sriov_numvfs = 7" | tee -a /etc/sysfs.conf > /dev/null || error_exit "Failed to update sysfs.conf"
        echo -e "${GREEN}Successfully configured sysfs for vGPU${NC}"
    fi
    print_separator


    # Prompt user for reboot
    echo -ne "${YELLOW}A reboot is required to apply the changes. Reboot now? (y/N): ${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo -e "\n${BLUE}Rebooting now...${NC}\n"
        reboot now
    else
        echo -e "\n${YELLOW}Reboot aborted. Please reboot manually later to apply changes.${NC}\n"
    fi
