#!/bin/bash
# VM Configuration Script
# This script sets up NFS mount and GitLab user configuration

set -e

echo "Starting VM configuration..."

# Update and install NFS client
echo "Installing NFS client..."
sudo apt update
sudo apt install nfs-common -y

# Create mount point and configure NFS
echo "Configuring NFS mount..."
sudo mkdir -p /mnt/files
echo "x.x.x.x:/filestore_nfs_2 /mnt/files nfs defaults,_netdev 0 0" | sudo tee -a /etc/fstab
sudo mount -a

# Configure GitLab SSH authorized keys
echo "Configuring GitLab SSH keys..."
sudo tee /home/gitlab/.ssh/authorized_keys > /dev/null <<EOF
EOF

# Copy deployment keys
echo "Copying deployment keys..."
sudo cp -r /mnt/files/deployment_keys/* /home/gitlab/.ssh/
sudo chown -R gitlab:gitlab /home/gitlab/.ssh/
sudo chmod -R 600 /home/gitlab/.ssh/

# Set proper permissions
echo "Setting permissions..."
sudo chmod -R 700 /home/gitlab/.ssh
sudo chown -R gitlab:gitlab /home/gitlab/
sudo chmod 600 /home/gitlab/.ssh/authorized_keys
sudo chmod 600 /home/gitlab/.ssh/id_rs*

# Add gitlab to www-data group
echo "Adding gitlab to www-data group..."
sudo usermod -aG www-data gitlab

# Unmount NFS share
echo "Unmounting NFS share..."
sudo umount /mnt/files

echo "VM configuration completed successfully!"
