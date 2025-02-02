# Proxmox Post Installation Script

## Overview

This script automates post-install configuration on a Proxmox VE system. It performs the following tasks:

- Configures NTP (using chrony) based on your detected country
- Disables the Proxmox subscription nag message
- Adjusts repository settings (disables Enterprise, enables Community)
- Installs and configures LLDP for Linux-style interface name reporting
- Downloads and installs the latest Intel Microcode update (v3.20241112.1)
- Upgrades server packages
- Provides interactive management for High Availability (HA) services
- Optionally installs a pretty login banner with system information
- Prompts for a system reboot at the end

## Dependencies

- Root privileges are required
- The following utilities must be available: 
  - curl
  - sed
  - wget
  - apt-get
  - dpkg
  - systemctl
  - dmidecode (for pretty login banner)
- An active network connection is necessary during execution

## Usage

1. Save the script as "post-install.sh"
2. Make the script executable:
   ```bash
   chmod +x post-install.sh
   ```
3. Run the script as root:
   ```bash
   sudo ./post-install.sh
   ```
4. Follow the interactive prompts to select your desired configuration options

## Key Features

- Interactive prompts for each major configuration step
- Detects your country using ipinfo.io to dynamically configure the NTP pool
- Creates backups of configuration files before modifications
- Configures LLDP with special handling for Intel X710 adapters
- Manages High Availability services for both clustered and single node setups
- Pretty login banner showing system information including:
  - Proxmox version
  - Server hardware details
  - System resources
  - Network information
  - System load

## Notes

- The script creates backups of configuration files before making modifications
- All major features can be selectively enabled/disabled through interactive prompts
- The pretty login banner requires dmidecode for hardware information
- A reboot is recommended after running the script to ensure all changes take effect

## Disclaimer

This script is provided "as-is" without any warranties. Use it at your own risk. Always verify all changes in a test environment before applying them to production systems.