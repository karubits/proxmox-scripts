#!/bin/bash
# proxmox-post-install.sh
# This script performs the following tasks:
#   1. Configures NTP (via chrony) based on your detected country.
#   2. Confirms that chrony is running and shows NTP sources.
#   3. Disables the Proxmox subscription nag.
#   4. Fixes repositories by disabling Enterprise and enabling Community.
#   5. Installs and configures LLDP.
#   6. Installs the latest Intel Microcode.
#   7. Upgrades the server.
#   8. Provides options to enable or disable High Availability (HA) services.
#   9. Optionally installs a pretty login banner.
#  10. Prompts for a reboot.
#
# Required utilities: curl, sed, apt, dpkg, wget
#
# ℹ️ More on MOTD customization: **[update-motd](https://www.google.com/search?q=update+motd)** {📝}

# ─── Color Variables ──────────────────────────────────────────────────
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"  # No Color

# ─── Utility Functions ────────────────────────────────────────────────
print_banner() {
    echo -e "\n${BLUE}========== $1 ==========${NC}\n"
}

ask_yes_no() {
    local prompt="$1 [y/n]: "
    while true; do
        read -r -p "$prompt" answer
        case "$answer" in
            [Yy]* ) return 0 ;;
            [Nn]* ) return 1 ;;
            * ) echo -e "${YELLOW}Please answer yes or no.${NC}" ;;
        esac
    done
}

# ─── Collect All Answers Upfront ──────────────────────────────────────
print_banner "Configuration Questions"

# Initialize variables to store answers
CONFIGURE_NTP=0
DISABLE_NAG=0
FIX_REPOS=0
INSTALL_LLDP=0
INSTALL_MICROCODE=0
UPGRADE_SERVER=0
ENABLE_HA=0
INSTALL_BANNER=0
REBOOT_AFTER=0

# Ask all questions upfront
echo -e "${YELLOW}Please answer the following questions to configure the script:${NC}\n"

if ask_yes_no "Do you want to configure NTP based on your country?"; then
    CONFIGURE_NTP=1
fi

if ask_yes_no "Do you want to disable the Proxmox subscription nag message?"; then
    DISABLE_NAG=1
fi

if ask_yes_no "Do you want to disable the Enterprise Repo and enable the Community Repo?"; then
    FIX_REPOS=1
fi

if ask_yes_no "Do you want to install LLDP and configure Linux-style interface name reporting?"; then
    INSTALL_LLDP=1
fi

if grep -q "Intel" /proc/cpuinfo; then
    if ask_yes_no "Do you want to install the latest Intel Microcode (v3.20250211.1)?"; then
        INSTALL_MICROCODE=1
    fi
fi

if ask_yes_no "Do you want to upgrade the server now?"; then
    UPGRADE_SERVER=1
fi

if systemctl is-active --quiet pve-ha-lrm; then
    if ask_yes_no "HA services are active. Do you want to disable HA services for a single node environment?"; then
        ENABLE_HA=1
    fi
else
    if ask_yes_no "HA services are not active. Do you want to enable HA services?"; then
        ENABLE_HA=1
    fi
fi

if ask_yes_no "Do you want to install a pretty login banner?"; then
    INSTALL_BANNER=1
fi

if ask_yes_no "Do you want to reboot the server after completion?"; then
    REBOOT_AFTER=1
fi

# Show summary of answers
print_banner "Configuration Summary"
echo -e "${YELLOW}The following actions will be performed:${NC}"
echo -e "  • Configure NTP: ${GREEN}$([ $CONFIGURE_NTP -eq 1 ] && echo "Yes" || echo "No")${NC}"
echo -e "  • Disable Subscription Nag: ${GREEN}$([ $DISABLE_NAG -eq 1 ] && echo "Yes" || echo "No")${NC}"
echo -e "  • Fix Repositories: ${GREEN}$([ $FIX_REPOS -eq 1 ] && echo "Yes" || echo "No")${NC}"
echo -e "  • Install LLDP: ${GREEN}$([ $INSTALL_LLDP -eq 1 ] && echo "Yes" || echo "No")${NC}"
echo -e "  • Install Intel Microcode: ${GREEN}$([ $INSTALL_MICROCODE -eq 1 ] && echo "Yes" || echo "No")${NC}"
echo -e "  • Upgrade Server: ${GREEN}$([ $UPGRADE_SERVER -eq 1 ] && echo "Yes" || echo "No")${NC}"
echo -e "  • HA Services: ${GREEN}$([ $ENABLE_HA -eq 1 ] && echo "Enable" || echo "Disable")${NC}"
echo -e "  • Install Login Banner: ${GREEN}$([ $INSTALL_BANNER -eq 1 ] && echo "Yes" || echo "No")${NC}"
echo -e "  • Reboot After: ${GREEN}$([ $REBOOT_AFTER -eq 1 ] && echo "Yes" || echo "No")${NC}"

if ! ask_yes_no "Do you want to proceed with these settings?"; then
    echo -e "${RED}Script aborted by user.${NC}"
    exit 1
fi

# ─── 1. Configure NTP via Chrony ───────────────────────────────────────
if [ $CONFIGURE_NTP -eq 1 ]; then
    print_banner "Configuring NTP"
    echo -e "${GREEN}Detecting your country via ${YELLOW}[ipinfo.io](https://www.google.com/search?q=ipinfo.io)${NC}"
    COUNTRY=$(curl -s ipinfo.io | grep '"country":' | cut -d'"' -f4)
    if [ -z "$COUNTRY" ]; then
        echo -e "${RED}Unable to detect country. Skipping NTP configuration.${NC}"
    else
        COUNTRY_LOWER=$(echo "$COUNTRY" | tr '[:upper:]' '[:lower:]')
        echo -e "${GREEN}Country detected: $COUNTRY (using NTP pool: ${COUNTRY_LOWER}.pool.ntp.org)${NC}"
        CHRONY_CONF="/etc/chrony/chrony.conf"
        if [ ! -f "$CHRONY_CONF" ]; then
            echo -e "${RED}Chrony configuration file not found at $CHRONY_CONF${NC}"
        else
            echo -e "${GREEN}Backing up ${CHRONY_CONF} to ${CHRONY_CONF}.bak${NC}"
            cp "$CHRONY_CONF" "${CHRONY_CONF}.bak"
            echo -e "${GREEN}Removing existing pool.ntp.org entries...${NC}"
            sed -i '/pool\.ntp\.org/d' "$CHRONY_CONF"
            echo -e "${GREEN}Adding new NTP server entries...${NC}"
            cat <<EOF >> "$CHRONY_CONF"
server 0.${COUNTRY_LOWER}.pool.ntp.org iburst
server 1.${COUNTRY_LOWER}.pool.ntp.org iburst
server 2.${COUNTRY_LOWER}.pool.ntp.org iburst
server 3.${COUNTRY_LOWER}.pool.ntp.org iburst
EOF
            echo -e "${GREEN}Restarting chrony service...${NC}"
            systemctl restart chrony

            # Confirm chrony is running (trimmed output)
            if systemctl is-active --quiet chrony; then
                echo -e "${GREEN}chrony is active (running).${NC}"
                echo -e "${GREEN}Current NTP sources (via ${YELLOW}[chronyc sources](https://www.google.com/search?q=chronyc+sources)${NC}):"
                chronyc sources
            else
                echo -e "${RED}chrony service is not active!${NC}"
            fi
        fi
    fi
fi

# ─── 2. Disable the Proxmox Subscription Nag ───────────────────────────
if [ $DISABLE_NAG -eq 1 ]; then
    print_banner "Disabling Subscription Nag"
    echo -e "${GREEN}Creating /etc/apt/apt.conf.d/no-nag-script...${NC}"
    cat <<'EOF' > /etc/apt/apt.conf.d/no-nag-script
DPkg::Post-Invoke { "dpkg -V proxmox-widget-toolkit | grep -q '/proxmoxlib\.js$'; if [ $? -eq 1 ]; then { echo 'Removing subscription nag from UI...'; sed -i '/.*data\.status.*{/{s/\!//;s/active/NoMoreNagging/}' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js; }; fi"; };
EOF
    echo -e "${GREEN}Triggering subscription nag removal...${NC}"
    dpkg -V proxmox-widget-toolkit | grep -q '/proxmoxlib\.js$'
    if [ $? -eq 1 ]; then
        sed -i '/.*data\.status.*{/{s/\!//;s/active/NoMoreNagging/}' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
        echo -e "${GREEN}Subscription nag removed.${NC}"
    else
        echo -e "${YELLOW}Subscription nag already removed or not present.${NC}"
    fi
fi

# ─── 3. Fix Repositories (Enterprise → Community) ─────────────────────
if [ $FIX_REPOS -eq 1 ]; then
    print_banner "Fixing Repositories"
    # Disable Enterprise repos
    if [ -f /etc/apt/sources.list.d/pve-enterprise.list ]; then
        echo -e "${GREEN}Commenting out entries in pve-enterprise.list...${NC}"
        sed -i 's/^[[:space:]]*\(deb\)/# \1/' /etc/apt/sources.list.d/pve-enterprise.list
    fi
    if [ -f /etc/apt/sources.list.d/ceph.list ]; then
        echo -e "${GREEN}Commenting out entries in ceph.list...${NC}"
        sed -i 's/^[[:space:]]*\(deb\)/# \1/' /etc/apt/sources.list.d/ceph.list
    fi
    
    # Create and configure Community Repo
    echo -e "${GREEN}Creating Proxmox VE Community Repository file...${NC}"
    cat <<EOF > /etc/apt/sources.list.d/pve-community.list
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
EOF
    
    echo -e "${GREEN}Updating package lists...${NC}"
    apt-get update
fi

# ─── 4. Install LLDP and Configure Interface Reporting ────────────────
if [ $INSTALL_LLDP -eq 1 ]; then
    print_banner "Installing LLDP"
    echo -e "${GREEN}Installing lldpd and sysfsutils...${NC}"
    apt-get install lldpd sysfsutils -y
    echo -e "${GREEN}Configuring lldpd...${NC}"
    echo "configure lldp portidsubtype ifname" | tee /etc/lldpd.conf > /dev/null
    
    # Check if Intel X710 adapters exist
    if [ -d "/sys/kernel/debug/i40e" ] && [ -n "$(ls -A /sys/kernel/debug/i40e/)" ]; then
        echo -e "${GREEN}Intel X710 adapters detected - disabling firmware-level LLDP...${NC}"
        
        # Add X710 NICs to sysfs.conf
        echo -e "${GREEN}Adding X710 NICs to sysfs.conf...${NC}"
        for dev in /sys/kernel/debug/i40e/*; do
            if [ -d "$dev" ]; then
                # Get NIC name from directory
                nic_name=$(basename "$dev")
                # Add entry to sysfs.conf if not already present
                if ! grep -q "class/net/$nic_name/device/i40e/$nic_name/fw_lldp" /etc/sysfs.conf; then
                    echo "class/net/$nic_name/device/i40e/$nic_name/fw_lldp = 0" >> /etc/sysfs.conf
                fi
                # Disable LLDP immediately
                echo "lldp stop" >> "$dev/command"
            fi
        done
    fi
    
    echo -e "${GREEN}Restarting lldpd service...${NC}"
    systemctl restart lldpd.service
    echo -e "${GREEN}LLDP installation and configuration complete.${NC}"
fi

# ─── 5. Install Latest Intel Microcode ────────────────────────────────
if [ $INSTALL_MICROCODE -eq 1 ]; then
    print_banner "Installing Intel Microcode"
    MICROCODE_DEB="intel-microcode_3.20250211.1_amd64.deb"
    URL="http://ftp.us.debian.org/debian/pool/non-free-firmware/i/intel-microcode/${MICROCODE_DEB}"
    echo -e "${GREEN}Installing iucode-tool...${NC}"
    apt-get install iucode-tool -y
    echo -e "${GREEN}Downloading Intel Microcode from:${NC} ${YELLOW}$URL${NC}"
    apt-get install wget -y
    wget -q "$URL" -O "$MICROCODE_DEB"
    if [ -f "$MICROCODE_DEB" ]; then
        echo -e "${GREEN}Installing Intel Microcode...${NC}"
        dpkg -i "$MICROCODE_DEB"
        rm -f "$MICROCODE_DEB"
    else
        echo -e "${RED}Failed to download Intel Microcode.${NC}"
    fi
fi

# ─── 6. Upgrade the Server ─────────────────────────────────────────────
if [ $UPGRADE_SERVER -eq 1 ]; then
    print_banner "Upgrading Server"
    echo -e "${GREEN}Updating package lists...${NC}"
    apt-get update
    echo -e "${GREEN}Upgrading packages (this may take a while)...${NC}"
    apt-get dist-upgrade -y
    echo -e "${GREEN}Server upgrade complete.${NC}"
fi

# ─── 7. High Availability (HA) Service Management ─────────────────────
if [ $ENABLE_HA -eq 1 ]; then
    print_banner "High Availability (HA) Management"
    if systemctl is-active --quiet pve-ha-lrm; then
        echo -e "${GREEN}Disabling HA services...${NC}"
        systemctl disable -q --now pve-ha-lrm
        systemctl disable -q --now pve-ha-crm
        systemctl disable -q --now corosync
        echo -e "${GREEN}HA services have been disabled.${NC}"
    else
        echo -e "${GREEN}Enabling HA services...${NC}"
        systemctl enable -q --now pve-ha-lrm
        systemctl enable -q --now pve-ha-crm
        systemctl enable -q --now corosync
        echo -e "${GREEN}HA services have been enabled.${NC}"
    fi
fi

# ─── 8. Install Pretty Login Banner ────────────────────────────────────
if [ $INSTALL_BANNER -eq 1 ]; then
    print_banner "Installing Pretty Login Banner"
    cat << 'EOF' > /etc/update-motd.d/10-system-summary
#!/bin/bash

KERNEL_VERSION=$(uname -r)
HOSTNAME=$(hostname)
# Gather only IPv4 addresses, one per line, and join them with ', '.
IP_ADDRESSES=$(hostname -I | tr ' ' '\n' | grep -E '^[0-9]+\.' | paste -sd ', ' -)
UPTIME=$(uptime -p | sed 's/^up //')
MEMORY=$(free -m | awk 'NR==2{printf "%s MB (Total) | %s MB (Free)", $2, $4}')
DISK_SPACE=$(df -h --total | awk 'END{printf "%s (Total) | %s (Free)", $2, $4}')
# Retrieve PVE version using the [pveversion](https://www.google.com/search?q=pveversion) command.
PVE_VERSION=$(pveversion | awk -F'/' '/pve-manager/ {print $2}' | awk '{print $1}')
LOAD_AVG=$(uptime | awk -F'load average:' '{ print $2 }')

# Check if running as root
if [ "$(id -u)" -eq 0 ]; then
    MANUFACTURER=$(dmidecode -s system-manufacturer)
    MODEL=$(dmidecode -s system-product-name)
    SERIAL=$(dmidecode -s system-serial-number)
    PROC=$(dmidecode -s processor-version | head -n 1)
else
    MANUFACTURER=$(sudo dmidecode -s system-manufacturer)
    MODEL=$(sudo dmidecode -s system-product-name)
    SERIAL=$(sudo dmidecode -s system-serial-number)
    PROC=$(sudo dmidecode -s processor-version | head -n 1)
fi

cat << EOM

🔶   ${HOSTNAME}  🔶

  🔹Proxmox Version : ${PVE_VERSION}
  🔹Server        : $MANUFACTURER $MODEL ($SERIAL)
  🔹Processor     : $PROC
  🔹Hostname      : $HOSTNAME
  🔹Kernel        : $KERNEL_VERSION
  🔹Uptime        : $UPTIME
  🔹Ip Addresses  : $IP_ADDRESSES
  🔹Memory        : $MEMORY
  🔹Disk Space    : $DISK_SPACE
  🔹Load Avg      : $LOAD_AVG

EOM
EOF
    chmod +x /etc/update-motd.d/10-system-summary
    echo -e "${GREEN}Pretty login banner installed.${NC}"

    # Clear static MOTD files to prevent duplicate or extra output.
    [ -f /etc/motd ] && > /etc/motd
    [ -f /etc/motd.tail ] && > /etc/motd.tail
    [ -f /var/run/motd ] && > /var/run/motd
fi

# ─── 9. Reboot if Requested ─────────────────────────────────────────────
if [ $REBOOT_AFTER -eq 1 ]; then
    print_banner "Rebooting Server"
    echo -e "${GREEN}Rebooting...${NC}"
    reboot
else
    echo -e "${YELLOW}Please remember to reboot the server later to finalize all changes.${NC}"
fi

print_banner "Post-install Configuration Complete"

