# Intel vGPU Setup Script for Proxmox

This script automates the setup of Intel vGPU (SR-IOV) on Proxmox VE systems with compatible Intel GPUs.

## Prerequisites

- Proxmox VE 7.x or later
- Compatible Intel GPU with SR-IOV support
- Root access or sudo privileges
- Git installed (`apt install git`)
- Internet connection for downloading dependencies

## Supported GPUs

The following Intel GPUs are known to support SR-IOV:
- Intel Arc A770
- Intel Arc A750
- Intel Arc A380
- Intel Data Center GPU Flex Series
- Other Intel GPUs with SR-IOV capability

## Installation

1. **Download the Script:**
   ```bash
   wget https://path.to/your/script/intel-vgpu-setup.sh
   ```

2. **Make it Executable:**
   ```bash
   chmod +x intel-vgpu-setup.sh
   ```

3. **Run the Script:**
   ```bash
   ./intel-vgpu-setup.sh
   ```

## What the Script Does

1. Backs up critical system files
2. Installs necessary dependencies
3. Clones and builds the i915-sriov-dkms driver
4. Configures GRUB for Intel vGPU support
5. Sets up required kernel parameters
6. Configures the system for SR-IOV operation

## Important Notes

- **Backup**: The script automatically creates backups of modified system files
- **Recovery**: If something goes wrong, you can boot into recovery mode and restore from backups
- **Reboot Required**: System reboot is required after script completion
- **Production Use**: Test thoroughly in a non-production environment first

## Troubleshooting

If you encounter issues:
1. Check the kernel logs: `dmesg | grep i915`
2. Verify IOMMU is enabled in BIOS
3. Ensure your GPU is in the supported list
4. Check if backups are present in their original locations with `.bak` extension

## Recovery

To restore from backup: