#!/bin/bash
# Script Name: Enable Intel iGPU on Proxmox
# Description: Enables the Intel iGPU on Proxmox by cloning and installing the
# i915-sriov-dkms module, updating GRUB configuration, and rebooting the system.
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

# Function to print an error message and exit
error_exit() {
    echo -e "\n${RED}Error: $1${NC}\n"
    exit 1
}

# Function to print a separator
print_separator() {
    echo -e "\n----------------------------------------------\n"
}

# Check for Intel GPU presence
echo -e "${BLUE}Checking for Intel GPU {💻}...${NC}"
if ! lspci | grep -i 'vga' | grep -i 'intel' > /dev/null; then
    error_exit "Intel GPU not detected. Exiting."
fi
echo -e "${GREEN}Intel GPU detected.${NC}"
print_separator

# Display a title banner
echo -e "${YELLOW}=============================================="
echo -e "       Intel iGPU Enabler for Proxmox"
echo -e "==============================================${NC}"
print_separator

# Explanation prompt with the steps
echo -e "${YELLOW}This script will perform the following steps:${NC}"
echo -e "${YELLOW}  1. Clone the i915-sriov-dkms repository into /tmp/ {📦}"
echo -e "  2. Check and install prerequisites (DKMS and build-essential) {🔧}"
echo -e "  3. Add and install the module via DKMS (if not already installed)"
echo -e "  4. Update GRUB configuration for iGPU support"
echo -e "  5. Update initramfs and prompt for a system reboot${NC}"
print_separator

echo -ne "${YELLOW}Do you want to continue? (y/n): ${NC}"
read -r answer
if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}Operation cancelled by user. Exiting.${NC}\n"
    exit 0
fi
print_separator

# Check if git is installed; if not, prompt for installation
if ! command -v git > /dev/null; then
    echo -e "${RED}git is not installed.${NC}"
    echo -ne "${YELLOW}Would you like to install git now? (y/n): ${NC}"
    read -r install_git
    if [[ "$install_git" =~ ^[Yy]$ ]]; then
        sudo apt update || error_exit "apt update failed during git installation."
        sudo apt install -y git || error_exit "Failed to install git."
        echo -e "${GREEN}git has been installed successfully.${NC}"
    else
        error_exit "git is required to proceed. Exiting."
    fi
fi
print_separator

# Create temporary directory for repository
REPO_DIR=$(mktemp -d)
if [ ! -d "$REPO_DIR" ]; then
    error_exit "Failed to create temporary directory."
fi

echo -e "${BLUE}Cloning i915-sriov-dkms repository into $REPO_DIR {📦}...${NC}"
sudo git clone https://github.com/strongtz/i915-sriov-dkms.git "$REPO_DIR" || error_exit "Failed to clone repository."
print_separator

# Check prerequisites: build-essential and dkms
echo -e "${BLUE}Checking prerequisites: build-essential and dkms {🔧}...${NC}"
if dpkg -s build-essential &>/dev/null && dpkg -s dkms &>/dev/null; then
    echo -e "${GREEN}build-essential and dkms are already installed.${NC}"
else
    echo -e "${BLUE}Installing prerequisites: build-essential and dkms {🔧}...${NC}"
    sudo apt update || error_exit "apt update failed."
    sudo apt install -y build-essential dkms || error_exit "Failed to install prerequisites."
fi
print_separator

# Change to the repository directory
echo -e "${BLUE}Changing directory to $REPO_DIR...${NC}"
cd "$REPO_DIR" || error_exit "Failed to change directory to $REPO_DIR."
print_separator

# Determine module version: extract from PKGBUILD if available, then VERSION file, else prompt.
if [ -f PKGBUILD ]; then
    VERSION=$(grep "^pkgver=" PKGBUILD | cut -d'=' -f2)
    echo -e "${GREEN}Version found in PKGBUILD: ${VERSION}${NC}"
elif [ -f VERSION ]; then
    VERSION=$(cat VERSION)
    echo -e "${GREEN}Version found in VERSION file: ${VERSION}${NC}"
else
    echo -e "${RED}No version information found in PKGBUILD or VERSION file.${NC}"
    echo -ne "${YELLOW}Would you like to specify a version manually? (y/n): ${NC}"
    read -r manual
    if [[ "$manual" =~ ^[Yy]$ ]]; then
        echo -ne "${YELLOW}Enter version string: ${NC}"
        read -r VERSION
        if [ -z "$VERSION" ]; then
            error_exit "No version provided. Exiting."
        fi
    else
        error_exit "Version information is required. Exiting."
    fi
fi
print_separator

# Check if a module with this version is already installed.
if sudo dkms status | grep -q "i915-sriov-dkms/${VERSION}"; then
    echo -e "${YELLOW}Module i915-sriov-dkms version ${VERSION} is already installed. Skipping DKMS add and install steps.${NC}"
else
    echo -e "${BLUE}Adding module to DKMS...${NC}"
    sudo dkms add . || error_exit "DKMS add failed."
    echo -e "${BLUE}Installing module version ${VERSION} using DKMS...${NC}"
    sudo dkms install -m i915-sriov-dkms -v "${VERSION}" --force || error_exit "DKMS install failed."
fi
print_separator

# Display DKMS status
echo -e "${BLUE}Displaying DKMS status...${NC}"
sudo dkms status || error_exit "DKMS status command failed."
print_separator

# Backup GRUB configuration
echo -e "${BLUE}Backing up GRUB configuration {⚙️}...${NC}"
TIMESTAMP=$(date +%y%m%d-%H%M)
sudo cp -a /etc/default/grub{,."$TIMESTAMP".bak} || error_exit "Failed to backup GRUB configuration."
print_separator

# Update GRUB configuration to enable Intel iGPU
echo -e "${BLUE}Updating GRUB configuration to enable Intel iGPU...${NC}"
sudo sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT/c\GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt i915.enable_guc=3 i915.max_vfs=7"' /etc/default/grub || error_exit "Failed to update GRUB configuration."
print_separator

# Update GRUB and initramfs
echo -e "${BLUE}Updating GRUB...${NC}"
sudo update-grub || error_exit "Failed to update GRUB."
print_separator

echo -e "${BLUE}Updating initramfs {🖥️}...${NC}"
sudo update-initramfs -u -k all || error_exit "Failed to update initramfs."
print_separator

# Configure sysfs for vGPU
echo -e "${BLUE}Configuring sysfs for vGPU...${NC}"
# Backup existing sysfs.conf if it exists
if [ -f /etc/sysfs.conf ]; then
    sudo cp /etc/sysfs.conf "/etc/sysfs.conf.${TIMESTAMP}.bak" || error_exit "Failed to backup sysfs.conf"
fi

# Add vGPU configuration to sysfs.conf
echo "devices/pci0000:00/0000:00:02.0/sriov_numvfs = 7" | sudo tee -a /etc/sysfs.conf > /dev/null || error_exit "Failed to update sysfs.conf"
echo -e "${GREEN}Successfully configured sysfs for vGPU${NC}"
print_separator

# Delete the temporary repository directory as it's no longer needed
echo -e "${BLUE}Deleting temporary repository directory $REPO_DIR...${NC}"
sudo rm -rf "$REPO_DIR" || echo -e "${YELLOW}Warning: Unable to delete $REPO_DIR. Please remove it manually.${NC}"
print_separator

# Prompt user for reboot
echo -ne "${YELLOW}A reboot is required to apply the changes. Reboot now? (y/N): ${NC}"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    echo -e "\n${BLUE}Rebooting now...${NC}\n"
    sudo reboot now
else
    echo -e "\n${YELLOW}Reboot aborted. Please reboot manually later to apply changes.${NC}\n"
fi
