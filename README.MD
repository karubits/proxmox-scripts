# Proxmox Administration Scripts

A collection of utility scripts to help automate and simplify various Proxmox VE administration tasks.

## Available Scripts

### 1. Proxmox Template Importer
**Location:** [`template-importer/`](template-importer/)

Automates the process of downloading, customizing, and importing cloud images as Proxmox VM templates. Features include:
- Support for multiple Linux distributions (Debian, Ubuntu, Fedora, Rocky Linux, AlmaLinux, etc.)
- Dynamic storage selection
- Image customization via `virt-customize`
- Cloud-Init template configuration
- Optional EFI support

### 2. Post-Installation Configuration
**Location:** [`post-install/`](post-install/)

Streamlines the post-installation configuration of a Proxmox VE system with features like:
- Automatic NTP configuration based on detected country
- Subscription notice removal
- Repository optimization
- LLDP configuration
- Intel microcode updates
- High Availability service management
- System package updates

### 3. Intel vGPU Enablement
**Location:** [`intel-vgpu-enablement/`](intel-vgpu-enablement/)

Automates the setup of Intel vGPU (SR-IOV) on Proxmox VE systems. Supports:
- Automatic driver installation and configuration
- GRUB configuration for vGPU support
- System preparation for SR-IOV operation

### 4. NVIDIA LXC Passthrough Guide
**Location:** [`nvidia/`](nvidia/)

Comprehensive guide for setting up NVIDIA GPU passthrough to LXC containers. Includes:
- Step-by-step driver installation
- Nouveau driver disablement
- LXC container configuration
- Verification steps
- Troubleshooting tips

## Prerequisites

- Proxmox VE .x or later
- Root access or sudo privileges
- Internet connection
- Basic understanding of Proxmox administration

## Contributing

Contributions are welcome! Please feel free to submit pull requests or create issues for bugs and feature requests.

## License

This project is licensed under the MIT License - see the individual script directories for specific details.

## Disclaimer

These scripts are provided as-is without warranty. Always test in a non-production environment first and ensure you have proper backups before running any automated scripts.

