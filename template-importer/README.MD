# Proxmox Cloud-Init Template Import Script

## Overview

This Bash script automates the process of downloading, customizing, and importing a cloud image as a Proxmox VM template. It supports a variety of Linux distributions—including Debian, Ubuntu (including Ubuntu 24.04 LTS Noble Numbat), Fedora, Rocky Linux, AlmaLinux, and more—while providing dynamic storage selection, optional EFI enablement, and distribution-specific image customization using `virt-customize`.

## Features

- **Alphabetically Sorted Cloud Images:** Choose from a pre-defined, sorted list of cloud images. Future updates are as easy as modifying the array in the script.
    
- **Dynamic Storage Selection:** Lists only those storages that support VM images by querying:
    
    pvesm status --content images
    
- **Image Customization:** Optionally customize the downloaded image using `virt-customize`. The script installs different package sets based on whether the image is Debian/Ubuntu or Red Hat–based (Rocky, AlmaLinux, Fedora, etc.).
    
- **Cloud-Init Template Configuration:** Prompt for template settings including:
    
    - Template Name (a default is suggested based on the selected image)
    - VM Template ID (defaulting to the next available ID, with a check to ensure it’s not already taken)
    - VM User and Password
    - DNS settings
    - EFI enablement (if desired)
- **EFI Support:** Enable EFI firmware (via `--bios ovmf`) for your VM template if required.
    

## Prerequisites

- **Proxmox VE Environment:** The script requires a Proxmox system with `qm`, `pvesm`, and `pvesh` commands installed.
- **Bash Shell** and utilities like `wget`.
- **Optional:** `virt-customize` from the **libguestfs-tools** package  
    Disclaimer: Installing **libguestfs-tools** on production systems is not advised.

## Installation

1. **Download the Script:**
    
    wget [https://path.to/your/script/import_template.sh](https://path.to/your/script/import_template.sh)
    
2. **Make the Script Executable:**
    
    chmod +x import_template.sh
    
3. **Run the Script:**
    
    ./import_template.sh
    

## Usage

When executed, the script will:

4. **Check for `virt-customize`:**  
    Prompts to install it if not found (with a production disclaimer).
5. **Present a Cloud Image Menu:**  
    Displays an alphabetically sorted list of available cloud images for selection.
6. **Download the Selected Image:**  
    Uses `wget` in quiet mode with a progress bar.
7. **Optional Image Customization:**  
    Installs basic packages using `virt-customize` with different package sets for Debian/Ubuntu versus Red Hat–based images.
8. **Select Storage:**  
    Lists available storages supporting VM images (via `pvesm status --content images`) for deployment.
9. **Prompt for Cloud-Init Settings:**  
    Collects template name, VM template ID (default is the next available ID), VM user, VM password, DNS settings, and whether to enable EFI.
10. **Import the Image as a VM Template:**  
    Creates the VM template, attaches the disk image, configures cloud-init settings, and converts the VM into a template.

## Configuration

- **Updating Cloud Images:**  
    The cloud images are defined in an array within the script in the following format:
    
    "Display Name|Download URL|Filename"
    
    To add or remove images, simply update this array. The list is automatically sorted alphabetically.
    
- **Package Customization:**  
    The script installs:
    
    - **For Debian/Ubuntu:** `qemu-guest-agent, lnav, ca-certificates, apt-transport-https, net-tools, dnsutils`
    - **For Red Hat–based images:** `qemu-guest-agent, lnav, ca-certificates, net-tools, bind-utils`

## Disclaimer

This script is provided **as-is** without any warranty. Use it at your own risk. Installing and customizing images on production systems should be performed with caution, and the installation of **libguestfs-tools** on production environments is not recommended.

## Related Links

- [Proxmox Cloud-Init Support](https://www.google.com/search?q=Proxmox+cloud-init) {💻}
- [virt-customize Documentation](https://www.google.com/search?q=virt-customize+documentation) {💻}
- [Proxmox VE Scripting Tutorials](https://www.google.com/search?q=Proxmox+VE+scripting) {🛠}

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

## Contributing

Contributions, suggestions, and bug reports are welcome. Feel free to fork the repository and submit pull requests to improve or extend the functionality of this script.