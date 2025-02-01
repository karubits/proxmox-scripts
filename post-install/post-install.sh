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
#   9. Prompts for a reboot.
#
# Required utilities: curl, sed, apt, dpkg, wget

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

# ─── 1. Configure NTP via Chrony ───────────────────────────────────────
if ask_yes_no "Do you want to configure NTP based on your country?"; then
    print_banner "Configuring NTP"
    echo -e "${GREEN}Detecting your country via [ipinfo.io](https://www.google.com/search?q=ipinfo.io)${NC}"
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
                echo -e "${GREEN}Current NTP sources (via [chronyc sources](https://www.google.com/search?q=chronyc+sources)):${NC}"
                chronyc sources
            else
                echo -e "${RED}chrony service is not active!${NC}"
            fi
        fi
    fi
fi

# ─── 2. Disable the Proxmox Subscription Nag ───────────────────────────
if ask_yes_no "Do you want to disable the Proxmox subscription nag message?"; then
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
if ask_yes_no "Do you want to disable the Enterprise Repo and enable the Community Repo?"; then
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
    # Enable Community Repo
    if [ -f /etc/apt/sources.list.d/pve-install-repo.list ]; then
        echo -e "${GREEN}Enabling community repo in pve-install-repo.list...${NC}"
        sed -i 's/^[[:space:]]*#//' /etc/apt/sources.list.d/pve-install-repo.list
    fi
    echo -e "${GREEN}Updating package lists...${NC}"
    apt-get update
fi

# ─── 4. Install LLDP and Configure Interface Reporting ────────────────
if ask_yes_no "Do you want to install LLDP and configure Linux-style interface name reporting?"; then
    print_banner "Installing LLDP"
    echo -e "${GREEN}Installing lldpd...${NC}"
    apt-get install lldpd -y
    echo -e "${GREEN}Configuring lldpd...${NC}"
    echo "configure lldp portidsubtype ifname" | tee /etc/lldpd.conf > /dev/null
    echo -e "${GREEN}Restarting lldpd service...${NC}"
    systemctl restart lldpd.service
    echo -e "${GREEN}LLDP installation and configuration complete.${NC}"
fi

# ─── 5. Install Latest Intel Microcode ────────────────────────────────
if ask_yes_no "Do you want to install the latest Intel Microcode (v3.20241112.1)?"; then
    print_banner "Installing Intel Microcode"
    MICROCODE_DEB="intel-microcode_3.20241112.1_amd64.deb"
    URL="http://ftp.us.debian.org/debian/pool/non-free-firmware/i/intel-microcode/${MICROCODE_DEB}"
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
if ask_yes_no "Do you want to upgrade the server now?"; then
    print_banner "Upgrading Server"
    echo -e "${GREEN}Updating package lists...${NC}"
    apt-get update
    echo -e "${GREEN}Upgrading packages (this may take a while)...${NC}"
    apt-get dist-upgrade -y
    echo -e "${GREEN}Server upgrade complete.${NC}"
fi

# ─── 7. High Availability (HA) Service Management ─────────────────────
print_banner "High Availability (HA) Management"

# If HA services are active, offer to disable them for single node setups.
if systemctl is-active --quiet pve-ha-lrm; then
    if ask_yes_no "HA services are active. Do you want to disable HA services for a single node environment?"; then
        echo -e "${GREEN}Disabling HA services...${NC}"
        systemctl disable -q --now pve-ha-lrm
        systemctl disable -q --now pve-ha-crm
        systemctl disable -q --now corosync
        echo -e "${GREEN}HA services have been disabled.${NC}"
    else
        echo -e "${YELLOW}Keeping HA services enabled.${NC}"
    fi
else
    if ask_yes_no "HA services are not active. Do you want to enable HA services?"; then
        echo -e "${GREEN}Enabling HA services...${NC}"
        systemctl enable -q --now pve-ha-lrm
        systemctl enable -q --now pve-ha-crm
        systemctl enable -q --now corosync
        echo -e "${GREEN}HA services have been enabled.${NC}"
    else
        echo -e "${YELLOW}HA services remain disabled.${NC}"
    fi
fi

# ─── 8. Prompt for Reboot ─────────────────────────────────────────────
if ask_yes_no "Do you want to reboot the server now?"; then
    print_banner "Rebooting Server"
    echo -e "${GREEN}Rebooting...${NC}"
    reboot
else
    echo -e "${YELLOW}Please remember to reboot the server later to finalize all changes.${NC}"
fi

print_banner "Post-install Configuration Complete"
