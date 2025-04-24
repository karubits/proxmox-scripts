# Installing NVIDIA Drivers on Proxmox for LXC Container Support

This guide will walk you through the process of installing NVIDIA drivers on Proxmox to enable GPU passthrough to LXC containers.

## Prerequisites

- A Proxmox server with an NVIDIA GPU
- Root access to the Proxmox server
- Internet connection

## Step 1: Disable Nouveau Driver

Create a configuration file to disable the Nouveau driver:

```bash
# Create configuration file to disable Nouveau
cat <<EOF > /etc/modprobe.d/disable-nouveau.conf
blacklist nouveau
options nouveau modeset=0
EOF

# Update initramfs and reboot
update-initramfs -u 
reboot
```

## Step 2: System Update and Package Installation

Update your system and install necessary packages:

```bash
# Update system packages
apt update
apt dist-upgrade -y
reboot now

# Clean up unused packages
apt autoremove -y

# Install required packages
apt install -y build-essential dkms pve-headers
```

## Step 3: Download and Install NVIDIA Driver

Download and install the NVIDIA driver (adjust the version number as needed):

```bash
# Download NVIDIA driver
wget https://us.download.nvidia.com/XFree86/Linux-x86_64/570.144/NVIDIA-Linux-x86_64-570.144.run

# Make the installer executable
chmod +x NVIDIA-Linux-x86_64-570.144.run

# Install the driver with DKMS support
./NVIDIA-Linux-x86_64-*.run --kernel-module-type=proprietary --dkms --no-install-libglvnd --no-x-check
```

## Step 4: Verify Installation

After installation, verify that the NVIDIA driver is working correctly:

```bash
nvidia-smi
```

You should see output similar to this:
```
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 570.144                Driver Version: 570.144        CUDA Version: 12.8     |
|-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  NVIDIA RTX A2000 12GB          Off |   00000000:01:00.0 Off |                  Off |
| 30%   59C    P0             24W /   70W |       0MiB /  12282MiB |      0%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+
```

## Step 5: Configure LXC Container

To enable GPU passthrough to LXC containers, you'll need to:

1. Add the following to your LXC container configuration:
   ```
   lxc.cgroup2.devices.allow: c 195:* rwm
   lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file
   lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file
   lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file
   ```

2. Install the NVIDIA driver inside the LXC container (same version as the host):
   ```bash
   ./NVIDIA-Linux-x86_64-*.run --no-kernel-module --no-install-libglvnd --no-x-check
   ```
   Note: We skip the kernel module installation as it was already performed on the host (Proxmox).

## Troubleshooting

- If you encounter issues with the driver installation, try removing the Nouveau driver first
- Make sure you're using the correct driver version for your GPU
- Check the Proxmox logs for any error messages
- Ensure the kernel headers match your running kernel version

## Notes

- The driver version used in this guide (570.144) should be updated to match the latest stable version for your GPU
- Always backup your system before making significant changes
- Some GPUs may require additional configuration for optimal performance 