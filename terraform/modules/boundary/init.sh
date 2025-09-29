#!/bin/bash
set -euo pipefail

# Log semua output ke file untuk debugging
exec > >(tee /var/log/boundary-init.log)
exec 2>&1

echo "=========================================="
echo "Memulai instalasi Boundary pada $(date)"
echo "=========================================="

# 1. Update sistem dan install klien MySQL
echo "[1/8] Memperbarui paket dan menginstal utilitas..."
apt-get update -y
apt-get install -y curl unzip mysql-client jq

# 2. Install Boundary
echo "[2/8] Menginstal Boundary versi ${BOUNDARY_VERSION}..."
curl -fsSL https://releases.hashicorp.com/boundary/${BOUNDARY_VERSION}/boundary_${BOUNDARY_VERSION}_linux_amd64.zip -o boundary.zip
unzip -o boundary.zip
sudo mv boundary /usr/local/bin/
rm boundary.zip

# Verify installation
boundary version

# 3. Buat user dan direktori Boundary
echo "[3/8] Membuat user dan direktori untuk Boundary..."
sudo useradd --system --home /etc/boundary --shell /bin/false boundary || true
sudo mkdir -p /etc/boundary /opt/boundary/data
sudo chown -R boundary:boundary /etc/boundary /opt/boundary

# 4. Unduh Sertifikat SSL Azure
echo "[4/8] Mengunduh sertifikat SSL database Azure..."
curl -sS --create-dirs -o /etc/boundary/DigiCertGlobalRootG2.crt.pem https://dl.cacerts.digicert.com/DigiCertGlobalRootG2.crt.pem
chown boundary:boundary /etc/boundary/DigiCertGlobalRootG2.crt.pem

# 5. Tunggu Database Siap
echo "[5/8] Menunggu database di host ${db_host} siap..."
MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if mysql --ssl-ca=/etc/boundary/DigiCertGlobalRootG2.crt.pem -h "${db_host}" -u "${db_username}" -p"${db_password}" -e "SELECT 1" &>/dev/null; then
        echo "✓ Database berhasil dihubungi!"
        break
    fi
    echo "  Menunggu database... percobaan $((RETRY_COUNT + 1))/$MAX_RETRIES"
    sleep 10
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "✗ ERROR: Waktu tunggu koneksi database habis."
    exit 1
fi

# 6. Buat database Boundary
echo "[6/8] Membuat database 'boundary' jika belum ada..."
mysql --ssl-ca=/etc/boundary/DigiCertGlobalRootG2.crt.pem \
    -h "${db_host}" \
    -u "${db_username}" \
    -p"${db_password}" \
    -e "CREATE DATABASE IF NOT EXISTS boundary CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
echo "✓ Database 'boundary' telah dibuat/diverifikasi."

# 7. Generate keys
echo "[7/8] Generate encryption keys..."
ROOT_KEY=$(openssl rand -base64 32)
RECOVERY_KEY=$(openssl rand -base64 32)

# Get public IP
PUBLIC_IP=$(curl -s -H Metadata:true --noproxy "*" --max-time 10 \
    "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2021-02-01&format=text" \
    || ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)

echo "Public IP: $PUBLIC_IP"

# 8. Buat file konfigurasi
echo "[8/8] Membuat file konfigurasi..."

DB_URL="mysql://${db_username}:${db_password}@tcp(${db_host}:3306)/boundary?tls=custom&x-tls-ca=/etc/boundary/DigiCertGlobalRootG2.crt.pem"
echo "DB URL (masked): mysql://${db_username}:***@tcp(${db_host}:3306)/boundary"

# Escape spesial karakter
ESCAPED_DB_URL=$(echo "$DB_URL" | sed -e 's/[&/\]/\\&/g')
ESCAPED_ROOT_KEY=$(echo "$ROOT_KEY" | sed -e 's/[&/\]/\\&/g')
ESCAPED_WORKER_AUTH_KEY=$(echo "${worker_auth_key}" | sed -e 's/[&/\]/\\&/g')
ESCAPED_RECOVERY_KEY=$(echo "$RECOVERY_KEY" | sed -e 's/[&/\]/\\&/g')

# Controller config
cat << 'CONTROLLER_CONFIG' | sed \
    -e "s|{{DB_URL}}|'"$ESCAPED_DB_URL"'|g" \
    -e "s|{{ROOT_KEY}}|'"$ESCAPED_ROOT_KEY"'|g" \
    -e "s|{{WORKER_AUTH_KEY}}|'"$ESCAPED_WORKER_AUTH_KEY"'|g" \
    -e "s|{{RECOVERY_KEY}}|'"$ESCAPED_RECOVERY_KEY"'|g" \
    > /etc/boundary/controller.hcl
disable_mlock = true

controller {
  name        = "boundary-controller"
  description = "Boundary controller"
  database {
    url = {{DB_URL}}
  }
}

listener "tcp" {
  address     = "0.0.0.0:9200"
  purpose     = "api"
  tls_disable = true
}

listener "tcp" {
  address     = "0.0.0.0:9201"
  purpose     = "cluster"
  tls_disable = true
}

kms "aead" {
  purpose   = "root"
  aead_type = "aes-gcm"
  key       = {{ROOT_KEY}}
  key_id    = "global_root"
}

kms "aead" {
  purpose   = "worker-auth"
  aead_type = "aes-gcm"
  key       = {{WORKER_AUTH_KEY}}
  key_id    = "global_worker_auth"
}

kms "aead" {
  purpose   = "recovery"
  aead_type = "aes-gcm"
  key       = {{RECOVERY_KEY}}
  key_id    = "global_recovery"
}
CONTROLLER_CONFIG

# Worker config
cat << 'WORKER_CONFIG' | sed \
    -e "s|{{PUBLIC_IP}}|$PUBLIC_IP|g" \
    -e "s|{{WORKER_AUTH_KEY}}|$ESCAPED_WORKER_AUTH_KEY|g" \
    > /etc/boundary/worker.hcl
disable_mlock = true

worker {
  name        = "boundary-worker"
  description = "Boundary worker"
  public_addr = "{{PUBLIC_IP}}"
  initial_upstreams = ["127.0.0.1:9201"]
}

listener "tcp" {
  address     = "0.0.0.0:9202"
  purpose     = "proxy"
  tls_disable = true
}

kms "aead" {
  purpose   = "worker-auth"
  aead_type = "aes-gcm"
  key       = "{{WORKER_AUTH_KEY}}"
  key_id    = "global_worker_auth"
}
WORKER_CONFIG

# Set permissions
sudo chown boundary:boundary /etc/boundary/*.hcl
sudo chmod 640 /etc/boundary/*.hcl

echo "=== Controller Config Check ==="
grep -v "key.*=" /etc/boundary/controller.hcl | head -20

# ================== SYSTEMD SERVICES ==================

# Controller service
cat > /etc/systemd/system/boundary-controller.service << 'CONTROLLER_SERVICE'
[Unit]
Description=HashiCorp Boundary Controller
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
User=boundary
Group=boundary
ExecStart=/usr/local/bin/boundary server -config=/etc/boundary/controller.hcl
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStartSec=300
TimeoutStopSec=30
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
CONTROLLER_SERVICE

# Worker service
cat > /etc/systemd/system/boundary-worker.service << 'WORKER_SERVICE'
[Unit]
Description=HashiCorp Boundary Worker
After=boundary-controller.service
Wants=boundary-controller.service

[Service]
Type=notify
User=boundary
Group=boundary
ExecStart=/usr/local/bin/boundary server -config=/etc/boundary/worker.hcl
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStartSec=300
TimeoutStopSec=30
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
WORKER_SERVICE

# Debug ensure files exist
echo "=== Service Files Created ==="
ls -l /etc/systemd/system/boundary-*.service

# Reload systemd
sudo systemctl daemon-reexec
sudo systemctl daemon-reload

# Initialize database
echo "=========================================="
echo "Initializing Boundary database..."
if ! sudo -u boundary /usr/local/bin/boundary database init -config /etc/boundary/controller.hcl; then
    echo "Database init warning (might already be initialized)"
fi

# Start services
echo "Starting Boundary services..."
sudo systemctl enable boundary-controller
sudo systemctl start boundary-controller

# Wait for controller
echo "Waiting for controller to start..."
sleep 15

if systemctl is-active --quiet boundary-controller; then
    echo "✓ Controller is running"

    sudo systemctl enable boundary-worker
    sudo systemctl start boundary-worker
    sleep 10

    if systemctl is-active --quiet boundary-worker; then
        echo "✓ Worker is running"
    else
        echo "✗ Worker failed to start"
        journalctl -u boundary-worker -n 20 --no-pager
    fi
else
    echo "✗ Controller failed to start"
    journalctl -u boundary-controller -n 20 --no-pager
    exit 1
fi

echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo "Controller API: http://$PUBLIC_IP:9200"
echo "Worker Proxy: $PUBLIC_IP:9202"
echo ""
echo "Service Status:"
systemctl status boundary-controller --no-pager -l | head -10
systemctl status boundary-worker --no-pager -l | head -10
echo "=========================================="
