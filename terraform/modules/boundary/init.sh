#!/bin/bash
set -euo pipefail

exec > >(tee /var/log/boundary-init.log)
exec 2>&1

echo "=========================================="
echo "Memulai instalasi Boundary pada $(date)"
echo "=========================================="

# 1. Update sistem dan install PostgreSQL client
echo "[1/8] Memperbarui paket dan menginstal utilitas..."
apt-get update -y
apt-get install -y curl unzip postgresql-client jq

# 2. Install Boundary
echo "[2/8] Menginstal Boundary versi ${BOUNDARY_VERSION}..."
curl -fsSL https://releases.hashicorp.com/boundary/${BOUNDARY_VERSION}/boundary_${BOUNDARY_VERSION}_linux_amd64.zip -o boundary.zip
unzip -o boundary.zip
sudo mv boundary /usr/local/bin/
rm boundary.zip

boundary version

# 3. Buat user dan direktori Boundary
echo "[3/8] Membuat user dan direktori untuk Boundary..."
sudo useradd --system --home /etc/boundary --shell /bin/false boundary || true
sudo mkdir -p /etc/boundary /opt/boundary/data
sudo chown -R boundary:boundary /etc/boundary /opt/boundary

# 4. Unduh Sertifikat SSL Azure untuk PostgreSQL
echo "[4/8] Mengunduh sertifikat SSL Azure..."
sudo curl -fsSL --create-dirs \
  -o /etc/boundary/DigiCertGlobalRootG2.crt.pem \
  https://cacerts.digicert.com/DigiCertGlobalRootG2.crt.pem

sudo chown boundary:boundary /etc/boundary/DigiCertGlobalRootG2.crt.pem

# 5. Tunggu Database PostgreSQL Siap
echo "[5/8] Menunggu database PostgreSQL di host ${db_host} siap..."
MAX_RETRIES=30
RETRY_COUNT=0

export PGPASSWORD="${db_password}"

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if psql "host=${db_host} port=5432 user=${db_username} dbname=postgres sslmode=require" -c "SELECT 1" &>/dev/null; then
        echo "✓ Database PostgreSQL berhasil dihubungi!"
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

# 6. Verifikasi database 'boundary' (sudah dibuat oleh Terraform)
echo "[6/8] Memverifikasi database 'boundary'..."
if psql "host=${db_host} port=5432 user=${db_username} dbname=boundary sslmode=require" -c "SELECT version();" &>/dev/null; then
    echo "✓ Database 'boundary' verified."
else
    echo "✗ WARNING: Database 'boundary' not found. Terraform should have created it."
fi

# 7. Generate encryption keys
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

# PostgreSQL connection string
DB_URL="postgresql://${db_username}:${encoded_db_password}@${db_host}:5432/boundary?sslmode=require"
echo "DB URL (masked): postgresql://${db_username}:***@${db_host}:5432/boundary"

# Escape special characters for sed
ESCAPED_DB_URL=$(echo "$DB_URL" | sed -e 's/[&/\\"]/\\&/g')
ESCAPED_ROOT_KEY=$(echo "$ROOT_KEY" | sed -e 's/[&/\\"]/\\&/g')
ESCAPED_WORKER_AUTH_KEY=$(echo "${worker_auth_key}" | sed -e 's/[&/\\"]/\\&/g')
ESCAPED_RECOVERY_KEY=$(echo "$RECOVERY_KEY" | sed -e 's/[&/\\"]/\\&/g')

# Controller config
cat << 'CONTROLLER_CONFIG' | sed \
    -e "s|{{DB_URL}}|\"$ESCAPED_DB_URL\"|g" \
    -e "s|{{ROOT_KEY}}|\"$ESCAPED_ROOT_KEY\"|g" \
    -e "s|{{WORKER_AUTH_KEY}}|\"$ESCAPED_WORKER_AUTH_KEY\"|g" \
    -e "s|{{RECOVERY_KEY}}|\"$ESCAPED_RECOVERY_KEY\"|g" \
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
    -e "s|{{WORKER_AUTH_KEY}}|\"$ESCAPED_WORKER_AUTH_KEY\"|g" \
    > /etc/boundary/worker.hcl
disable_mlock = true

worker {
  name        = "boundary-worker"
  description = "Boundary worker"
  public_addr = "{{PUBLIC_IP}}"
  initial_upstreams = ["localhost:9201"]
}

listener "tcp" {
  address     = "0.0.0.0:9202"
  purpose     = "proxy"
  tls_disable = true
}

kms "aead" {
  purpose   = "worker-auth"
  aead_type = "aes-gcm"
  key       = {{WORKER_AUTH_KEY}}
  key_id    = "global_worker_auth"
}
WORKER_CONFIG

sudo chown boundary:boundary /etc/boundary/*.hcl
sudo chmod 640 /etc/boundary/*.hcl

echo "=== Controller Config Check ==="
grep -v "key.*=" /etc/boundary/controller.hcl | head -20

# ================== SYSTEMD SERVICES ==================

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

echo "=== Service Files Created ==="
ls -l /etc/systemd/system/boundary-*.service

sudo chown root:root /etc/systemd/system/boundary-*.service
sudo chmod 644 /etc/systemd/system/boundary-*.service

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
echo "Database Info:"
echo "  Type: PostgreSQL"
echo "  Host: ${db_host}"
echo "  Database: boundary"
echo ""
systemctl status boundary-controller --no-pager -l | head -10
systemctl status boundary-worker --no-pager -l | head -10
echo "=========================================="
