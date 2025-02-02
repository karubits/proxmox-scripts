# Intel GPU Virtualization Enabler for Proxmox

This script automates the setup of Intel GPU virtualization (vGPU) on Proxmox by configuring SR-IOV on the integrated Intel GPU. It handles the installation of the required i915-sriov-dkms module, GRUB configuration, and system settings for GPU virtualization.

## Prerequisites

- Proxmox VE installed
- Intel GPU with SR-IOV support
- Root access to the system
- Internet connection for downloading packages

## Features

- 🔍 Automatic detection of Intel GPU
- 📦 Automated installation of required dependencies
- 🔧 Installation of the latest i915-sriov-dkms package
- ⚙️ GRUB configuration for vGPU support
- 🖥️ Configuration of virtual GPU functions via sysfs
- 💾 Automatic backup of modified configuration files

## Usage

1. Download the script:
`bash wget https://raw.githubusercontent.com/karubits/proxmox-scripts/refs/heads/main/intel-vgpu-enablement/intel-vgpu-setup.sh`
2. Make it executable:
`chmod +x intel-vgpu-setup.sh`
3. Run the script:
`./intel-vgpu-setup.sh`

## What the Script Does

1. Installs required dependencies
2. Downloads and installs the latest i915-sriov-dkms package for GPU virtualization
3. Updates GRUB configuration for vGPU support
4. Configures sysfs for virtual GPU functions
5. Updates initramfs and prompts for a system reboot

## Configuration

The script configures the following settings:

- GRUB parameters:
  - `intel_iommu=on`: Enables IOMMU for Intel processors
  - `i915.enable_guc=3`: Enables GuC submission
  - `i915.max_vfs=7`: Sets maximum number of virtual functions
  - `module_blacklist=xe`: Blacklists the xe driver for Linux VM support

- Sysfs configuration:
  - Sets `sriov_numvfs = 7` for the Intel GPU

## Backup

The script automatically creates backups of modified configuration files:
- GRUB configuration: `/etc/default/grub.YYYYMMDD-HHMM.bak`
- Sysfs configuration: `/etc/sysfs.conf.YYYYMMDD-HHMM.bak`

## Troubleshooting

If you encounter issues:

1. Check if your Intel GPU supports SR-IOV
2. Verify that virtualization is enabled in BIOS/UEFI
3. Check the DKMS status: `dkms status`
4. Review system logs: `journalctl -b`

## Credits

This script utilizes:
- [i915-sriov-dkms](https://github.com/strongtz/i915-sriov-dkms) by strongtz

