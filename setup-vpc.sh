#!/usr/bin/bash

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
fi

# Detect OS
OS_TYPE=""
if grep -qi "kali" /etc/os-release; then
    OS_TYPE="kali"
elif grep -qi "debian" /etc/os-release; then
    OS_TYPE="debian"
else
    echo "Unsupported operating system. This script is designed for Debian or Kali Linux." >&2
    exit 1
fi

# Prompt for new hostname
read -rp "Enter the new hostname: " NEW_HOSTNAME

# Validate input
if [[ -z "$NEW_HOSTNAME" ]]; then
    echo "Hostname cannot be empty." >&2
    exit 1
fi

# Get current hostname
CURRENT_HOSTNAME=$(hostname)

# Update /etc/hostname
echo "$NEW_HOSTNAME" > /etc/hostname

# Update /etc/hosts
sed -i "s/$CURRENT_HOSTNAME/$NEW_HOSTNAME/g" /etc/hosts

# Apply the new hostname
hostnamectl set-hostname "$NEW_HOSTNAME"

# Regenerate SSH host keys
echo "Regenerating SSH host keys..."
rm -f /etc/ssh/ssh_host_*
dpkg-reconfigure openssh-server

# Ensure unique machine ID
echo "Regenerating machine ID..."
rm -f /etc/machine-id
systemd-machine-id-setup

# Generate self-signed certificate for xrdp
XRDP_CERT_DIR="/etc/xrdp"
XRDP_CERT_FILE="$XRDP_CERT_DIR/xrdp-cert.pem"
XRDP_KEY_FILE="$XRDP_CERT_DIR/xrdp-key.pem"

# Set XRDP_USER based on OS type
if [ "$OS_TYPE" = "kali" ]; then
    XRDP_USER="xrdp"
else
    XRDP_USER="mujin"
fi

echo "Generating 10-year self-signed certificate for xrdp..."
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$XRDP_KEY_FILE" -out "$XRDP_CERT_FILE" -days 3650 -subj "/CN=$NEW_HOSTNAME"

# Set appropriate permissions based on OS type
chmod 640 "$XRDP_CERT_FILE" "$XRDP_KEY_FILE"
chown "$XRDP_USER:$XRDP_USER" "$XRDP_CERT_FILE" "$XRDP_KEY_FILE"

# Update xrdp configuration
sed -i "s|^certificate=.*|certificate=$XRDP_CERT_FILE|" /etc/xrdp/xrdp.ini
sed -i "s|^key_file=.*|key_file=$XRDP_KEY_FILE|" /etc/xrdp/xrdp.ini

if [ "$OS_TYPE" = "kali" ]; then
    echo "Configured xrdp certificates for Kali Linux"
else
    echo "Configured xrdp certificates for Debian"
fi

echo "Hostname successfully changed to '$NEW_HOSTNAME'."
echo "Self-signed xrdp certificate generated and applied."

# Reboot system
echo "Rebooting system in 5 seconds..."
sleep 5
reboot