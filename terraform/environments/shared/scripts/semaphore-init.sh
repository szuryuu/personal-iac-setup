#!/bin/bash
set -euo pipefail

exec > >(tee /var/log/semaphore-install.log)
exec 2>&1

echo "=========================================="
echo "Semaphore Installation - $(date)"
echo "=========================================="

# Update system
echo "[+] Updating system..."
apt-get update -y
apt-get upgrade -y

# Install Docker
echo "[+] Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
systemctl enable docker
systemctl start docker
usermod -aG docker adminuser

# Install Docker Compose
echo "[+] Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Setup data disk
echo "[+] Setting up data disk..."
mkdir -p /mnt/semaphore-data/{db,ssh,ansible}
chown -R 1001:1001 /mnt/semaphore-data

# Setup SSH key
echo "[+] Setting up SSH keys..."
cat > /mnt/semaphore-data/ssh/id_rsa << 'EOF'
${ssh_private_key}
EOF
chown 1001:1001 /mnt/semaphore-data/ssh/id_rsa
chmod 600 /mnt/semaphore-data/ssh/id_rsa

# Setup SSH config
echo "[+] Setting up SSH config..."
cat > /mnt/semaphore-data/ssh/config << 'EOF'
# DEV ENVIRONMENT
Host dev-boundary
  HostName ${dev_boundary_ip}
  User adminuser
  IdentityFile /etc/semaphore/id_rsa
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null

Host dev-vm
  HostName ${dev_vm_ip}
  User adminuser
  IdentityFile /etc/semaphore/id_rsa
  ProxyJump dev-boundary
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
EOF
chown 1001:1001 /mnt/semaphore-data/ssh/config
chmod 644 /mnt/semaphore-data/ssh/config

# Clone Ansible repo (if Git URL provided)
echo "[+] Cloning Ansible repository..."
if [ ! -z "${ansible_repo_url}" ]; then
    git clone ${ansible_repo_url} /mnt/semaphore-data/piac
    chown -R 1001:1001 /mnt/semaphore-data/piac/ansible
fi

# Setup Docker Compose
echo "[+] Setting up Semaphore with Docker Compose..."
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
      - /mnt/semaphore-data/piac/ansible:/ansible
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
echo ""
echo "Environments configured:"
echo "  - DEV: ${dev_vm_ip} (via ${dev_boundary_ip})"
echo "=========================================="
