#!/bin/bash
set -euo pipefail

exec > >(tee /var/log/semaphore-install.log)
exec 2>&1

echo "=========================================="
echo "Semaphore Installation - $(date)"
echo "=========================================="

# Update system
echo "[1/8] Updating system..."
apt-get update -y
apt-get upgrade -y

# Install Docker
echo "[2/8] Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
systemctl enable docker
systemctl start docker

# Add adminuser to docker group
usermod -aG docker adminuser

# Install Docker Compose
echo "[3/8] Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Setup data disk
echo "[4/8] Setting up data disk..."
DATA_DISK="/dev/sdc"
if [ -b "$DATA_DISK" ]; then
    mkfs.ext4 $DATA_DISK
    mkdir -p /mnt/semaphore-data
    mount $DATA_DISK /mnt/semaphore-data
    echo "$DATA_DISK /mnt/semaphore-data ext4 defaults,nofail 0 2" >> /etc/fstab

    # Create directories
    mkdir -p /mnt/semaphore-data/{db,ssh,ansible}
    chown -R 1001:1001 /mnt/semaphore-data
fi

# Setup SSH key
echo "[5/8] Setting up SSH keys..."
cat > /mnt/semaphore-data/ssh/id_rsa << 'EOF'
${ssh_private_key}
EOF
chown 1001:1001 /mnt/semaphore-data/ssh/id_rsa
chmod 600 /mnt/semaphore-data/ssh/id_rsa

# Setup SSH config
echo "[6/8] Setting up SSH config..."
cat > /mnt/semaphore-data/ssh/config << 'EOF'
Host boundary
  HostName ${boundary_ip}
  User adminuser
  IdentityFile /etc/semaphore/id_rsa
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null

Host vm-dev
  HostName ${vm_dev_ip}
  User adminuser
  IdentityFile /etc/semaphore/id_rsa
  ProxyJump boundary
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
EOF
chown 1001:1001 /mnt/semaphore-data/ssh/config
chmod 644 /mnt/semaphore-data/ssh/config

# Clone Ansible repo (if Git URL provided)
echo "[7/8] Cloning Ansible repository..."
if [ ! -z "${ansible_repo_url}" ]; then
    git clone ${ansible_repo_url} /mnt/semaphore-data/ansible
    chown -R 1001:1001 /mnt/semaphore-data/ansible
fi

# Setup Docker Compose
echo "[8/8] Setting up Semaphore with Docker Compose..."
cat > /home/adminuser/docker-compose.yml << 'EOF'
version: '3.8'

services:
  semaphore:
    image: semaphoreui/semaphore:latest
    container_name: semaphore
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      SEMAPHORE_DB_DIALECT: ${db_dialect}
      SEMAPHORE_ADMIN: admin
      SEMAPHORE_ADMIN_PASSWORD: ${admin_password}
      SEMAPHORE_ADMIN_NAME: Admin
      SEMAPHORE_ADMIN_EMAIL: admin@localhost
      ANSIBLE_LOCAL_TEMP: /tmp
      SEMAPHORE_TMP_PATH: /tmp
      ANSIBLE_GALAXY_CACHE_DIR: /tmp
      ANSIBLE_GALAXY_SERVER_CACHE_PATH: /tmp
    volumes:
      - /mnt/semaphore-data/db:/tmp/semaphore
      - /mnt/semaphore-data/ansible:/ansible
      - /mnt/semaphore-data/ssh/id_rsa:/etc/semaphore/id_rsa:ro
      - /mnt/semaphore-data/ssh/config:/etc/semaphore/ssh_config:ro
    networks:
      - semaphore-net

networks:
  semaphore-net:
    driver: bridge
EOF

chown adminuser:adminuser /home/adminuser/docker-compose.yml

# Start Semaphore
echo "Starting Semaphore..."
cd /home/adminuser
docker-compose up -d

echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo "Semaphore URL: http://$(curl -s ifconfig.me):3000"
echo "Username: admin"
echo "Password: ${admin_password}"
echo "=========================================="
