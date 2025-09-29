#!/bin/bash
set -e

# log
exec > >(tee /var/log/boundary-init.log)
exec 2>&1

echo "Starting Boundary installation at $(date)"

# Update system
apt-get update
apt-get install -y curl unzip mysql-client

# Install Boundary worker
curl -fsSL https://releases.hashicorp.com/boundary/${BOUNDARY_VERSION}/boundary_${BOUNDARY_VERSION}_linux_amd64.zip -o boundary.zip
unzip boundary.zip
sudo mv boundary /usr/local/bin/
rm boundary.zip

# Verify installation
boundary version

# Create boundary user and directories
echo "Creating boundary user and directories"
sudo useradd --system --home /etc/boundary --shell /bin/false boundary
sudo mkdir -p /etc/boundary /opt/boundary/data
sudo chown -R boundary:boundary /etc/boundary /opt/boundary

# Generate keys
echo "Generating encryption keys"
ROOT_KEY=$(openssl rand -base64 32)
# WORKER_AUTH_KEY=$(openssl rand -base64 32)
RECOVERY_KEY=$(openssl rand -base64 32)

# Get public IP
echo "Fetching public IP"
PUBLIC_IP=$(curl -H Metadata:true --noproxy "*" \
  "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2021-02-01&format=text" 2>/dev/null || echo "127.0.0.1")

echo "Public IP: $PUBLIC_IP"

# Wait for database to be ready and create database
echo "Waiting for database to be ready..."
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if mysql -h "${db_host}" -u "${db_username}" -p"${db_password}" -e "SELECT 1" &>/dev/null; then
        echo "Database is ready!"
        break
    fi
    echo "Waiting for database... attempt $((RETRY_COUNT + 1))/$MAX_RETRIES"
    sleep 10
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "ERROR: Database connection timeout"
    exit 1
fi

# Create boundary database if it doesn't exist
echo "Creating boundary database"
mysql -h "${db_host}" -u "${db_username}" -p"${db_password}" <<EOF
CREATE DATABASE IF NOT EXISTS boundary CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
SHOW DATABASES;
EOF

# --- Controller config ---
echo "Creating controller configuration"
cat > /etc/boundary/controller.hcl <<'EOFCONTROLLER'
disable_mlock = true

controller {
  name        = "controller-${environment}"
  description = "Controller untuk ${environment} environment"

  database {
    kind     = "mysql"
    host     = "${db_host}"
    port     = 3306
    database = "boundary"
    username = "${db_username}"
    password = "${db_password}"

    max_open_conns = 100
    ssl_mode       = "required"
  }
}

listener "tcp" {
  address = "0.0.0.0:9200"
  purpose = "api"
  tls_disable = true
}

listener "tcp" {
  address = "127.0.0.1:9201"
  purpose = "cluster"
  tls_disable = true
}

kms "aead" {
  purpose    = "root"
  aead_type  = "aes-gcm"
  key        = "ROOT_KEY_PLACEHOLDER"
  key_id     = "global_root"
}

kms "aead" {
  purpose    = "worker-auth"
  aead_type  = "aes-gcm"
  key        = "${worker_auth_key}"
  key_id     = "worker_auth"
}

kms "aead" {
  purpose    = "recovery"
  aead_type  = "aes-gcm"
  key        = "RECOVERY_KEY_PLACEHOLDER"
  key_id     = "recovery"
}

log {
  level = "info"
  format = "standard"
}
EOFCONTROLLER

sed -i "s|ROOT_KEY_PLACEHOLDER|$ROOT_KEY|g" /etc/boundary/controller.hcl
sed -i "s|RECOVERY_KEY_PLACEHOLDER|$RECOVERY_KEY|g" /etc/boundary/controller.hcl

sudo chown boundary:boundary /etc/boundary/controller.hcl
sudo chmod 640 /etc/boundary/controller.hcl

# --- Worker config ---
echo "Creating worker configuration"
cat > /etc/boundary/worker.hcl <<'EOFWORKER'
disable_mlock = true

worker {
  name        = "azure-worker-$(hostname)"
  description = "Azure Boundary worker"
  controllers = ["127.0.0.1:9201"]
  public_addr = "PUBLIC_IP_PLACEHOLDER"
}

listener "tcp" {
  address = "0.0.0.0:9202"
  purpose = "proxy"
  tls_disable = true
}

kms "aead" {
  purpose   = "worker-auth"
  aead_type = "aes-gcm"
  key       = "${worker_auth_key}"
  key_id    = "worker_auth"
}

log {
  level  = "info"
  format = "standard"
}
EOFWORKER

sed -i "s|PUBLIC_IP_PLACEHOLDER|$PUBLIC_IP|g" /etc/boundary/worker.hcl

sudo chown boundary:boundary /etc/boundary/worker.hcl
sudo chmod 640 /etc/boundary/worker.hcl

# --- systemd service: controller ---
echo "Creating controller systemd service"
cat > /etc/systemd/system/boundary-controller.service <<'EOFSERVICE'
[Unit]
Description=HashiCorp Boundary Controller
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
User=boundary
Group=boundary
ExecStart=/usr/local/bin/boundary server -config=/etc/boundary/controller.hcl
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5
LimitMEMLOCK=infinity
AmbientCapabilities=CAP_IPC_LOCK
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOFSERVICE

# --- systemd service: worker ---
echo "Creating worker systemd service"
cat > /etc/systemd/system/boundary-worker.service <<'EOFSERVICE'
[Unit]
Description=HashiCorp Boundary Worker
After=network-online.target boundary-controller.service
Wants=network-online.target
Requires=boundary-controller.service

[Service]
Type=notify
User=boundary
Group=boundary
ExecStart=/usr/local/bin/boundary server -config=/etc/boundary/worker.hcl
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5
LimitMEMLOCK=infinity
AmbientCapabilities=CAP_IPC_LOCK
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOFSERVICE

echo "Reloading systemd daemon"
sudo systemctl daemon-reload

# Initialize database
echo "Initializing Boundary database"
sleep 5
sudo -u boundary /usr/local/bin/boundary database init -config=/etc/boundary/controller.hcl 2>&1 | tee /var/log/boundary-db-init.log || {
    echo "Database init failed or already initialized"
    cat /var/log/boundary-db-init.log
}

# Start controller
echo "Starting Boundary controller"
sudo systemctl enable boundary-controller
sudo systemctl start boundary-controller

# Wait for controller to be ready
echo "Waiting for controller to start..."
sleep 20

# Check controller status
sudo systemctl status boundary-controller --no-pager || true

# Start worker
echo "Starting Boundary worker"
sudo systemctl enable boundary-worker
sudo systemctl start boundary-worker

# Wait for worker to start
sleep 10

# Check worker status
sudo systemctl status boundary-worker --no-pager || true

# Final status check
echo "Final status check:"
sudo systemctl is-active boundary-controller
sudo systemctl is-active boundary-worker

# Check if ports are listening
echo "Checking listening ports:"
ss -tlnp | grep -E '9200|9201|9202' || echo "Boundary ports not listening yet"

echo "Boundary installation completed at $(date)"
echo "Check logs with: sudo journalctl -u boundary-controller -f"
echo "                 sudo journalctl -u boundary-worker -f"
