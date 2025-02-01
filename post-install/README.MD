# Proxmox Post Installation Script

## Overview:

This script automates post-install configuration on a Proxmox VE system. It performs the following tasks: • Configures NTP (using chrony) based on your detected country. • Verifies that the chrony service is active and displays current NTP sources. • Disables the Proxmox subscription nag message. • Adjusts repository settings by disabling the Enterprise repository and enabling the Community repository. • Installs and configures LLDP for Linux-style interface name reporting. • Downloads and installs the latest Intel Microcode update. • Upgrades server packages. • Provides interactive management for High Availability (HA) services. • Prompts for a system reboot at the end.

## Dependencies:

- Root privileges are required.
- The following utilities must be available: curl, sed, wget, apt-get, dpkg, systemctl.
- This script is designed and tested for Proxmox VE environments.
- An active network connection is necessary during execution.

## Usage:

1. Save this script as "proxmox-post-install.sh".
2. Make the script executable: chmod +x proxmox-post-install.sh
3. Run the script as root: sudo ./proxmox-post-install.sh
4. Follow the interactive prompts to select your desired configuration options.

## Key Features:

- Detects your country using ipinfo.io to dynamically configure the NTP pool.
- Confirms chrony is running (without full systemctl output) and displays current NTP sources via "chronyc sources".
- Adjusts repositories by disabling Enterprise and enabling Community sources before installing packages.
- Offers interactive options to enable or disable High Availability (HA) services for clustered or single node setups.
- Prompts for a reboot at the end to ensure that all changes are applied.

## Notes:

- The script creates backups of configuration files before making modifications.
- Ensure you have proper backups of your system and configurations before executing any automated script.
- This script should be tested in a non-production environment prior to widespread deployment.

## Disclaimer:

This script is provided "as-is" without any warranties. Use it at your own risk. Verify all changes in your environment before applying them to production systems.