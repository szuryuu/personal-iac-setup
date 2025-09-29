#!/bin/bash
set -e

# Log semua output ke file untuk debugging
exec > >(tee /var/log/boundary-init.log)
exec 2>&1

echo "=========================================="
echo "Memulai instalasi Boundary pada $(date)"
echo "=========================================="

# 1. Update sistem dan install klien MySQL
echo "[1/7] Memperbarui paket dan menginstal utilitas..."
apt-get update
apt-get install -y curl unzip mysql-client

# 2. Install Boundary
echo "[2/7] Menginstal Boundary versi ${BOUNDARY_VERSION}..."
curl -fsSL https://releases.hashicorp.com/boundary/${BOUNDARY_VERSION}/boundary_${BOUNDARY_VERSION}_linux_amd64.zip -o boundary.zip
unzip -o boundary.zip
sudo mv boundary /usr/local/bin/
rm boundary.zip

# 3. Buat user dan direktori Boundary
echo "[3/7] Membuat user dan direktori untuk Boundary..."
sudo useradd --system --home /etc/boundary --shell /bin/false boundary || true
sudo mkdir -p /etc/boundary /opt/boundary/data
sudo chown -R boundary:boundary /etc/boundary /opt/boundary

# 4. Unduh Sertifikat SSL Azure
echo "[4/7] Mengunduh sertifikat SSL database Azure..."
curl -sS --create-dirs -o /etc/boundary/DigiCertGlobalRootG2.crt.pem https://dl.cacerts.digicert.com/DigiCertGlobalRootG2.crt.pem
chown boundary:boundary /etc/boundary/DigiCertGlobalRootG2.crt.pem

# 5. Tunggu Database Siap (Langkah Kunci)
echo "[5/7] Menunggu database di host ${db_host} siap..."
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
echo "[6/7] Membuat database 'boundary' jika belum ada..."
mysql --ssl-ca=/etc/boundary/DigiCertGlobalRootG2.crt.pem -h "${db_host}" -u "${db_username}" -p"${db_password}" -e "CREATE DATABASE IF NOT EXISTS boundary CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
echo "✓ Database 'boundary' telah dibuat/diverifikasi."

# 7. Buat Konfigurasi dan Jalankan Layanan
echo "[7/7] Membuat file konfigurasi dan layanan systemd..."

# Dapatkan IP Publik
PUBLIC_IP=$(curl -s -H Metadata:true --noproxy "*" --max-time 10 "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2021-02-01&format=text" || ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)

# Buat Kunci Enkripsi
ROOT_KEY=$(openssl rand -base64 32)
RECOVERY_KEY=$(openssl rand -base64 32)

# Buat file controller.hcl
cat > /etc/boundary/controller.hcl << EOF
disable_mlock = true
controller {
  name        = "controller-dev"
  description = "Controller untuk dev environment"
  database {
    url = "mysql://${db_username}:${db_password}@tcp(${db_host}:3306)/boundary?tls=custom&x-tls-ca=/etc/boundary/DigiCertGlobalRootG2.crt.pem"
  }
}
listener "tcp" {
  address     = "0.0.0.0:9200"
  purpose     = "api"
  tls_disable = true
}
listener "tcp" {
  address     = "127.0.0.1:9201"
  purpose     = "cluster"
  tls_disable = true
}
kms "aead" {
  purpose   = "root"
  aead_type = "aes-gcm"
  key       = "$ROOT_KEY"
  key_id    = "global_root"
}
kms "aead" {
  purpose   = "worker-auth"
  aead_type = "aes-gcm"
  key       = "${worker_auth_key}"
  key_id    = "worker_auth"
}
kms "aead" {
  purpose   = "recovery"
  aead_type = "aes-gcm"
  key       = "$RECOVERY_KEY"
  key_id    = "recovery"
}
log {
  level  = "info"
  format = "standard"
}
EOF

# Buat file worker.hcl
cat > /etc/boundary/worker.hcl << EOF
disable_mlock = true
worker {
  name        = "azure-worker-$(hostname)"
  description = "Azure Boundary worker"
  controllers = ["127.0.0.1:9201"]
  public_addr = "$PUBLIC_IP"
}
listener "tcp" {
  address     = "0.0.0.0:9202"
  purpose     = "proxy"
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
EOF

# Atur izin file
sudo chown boundary:boundary /etc/boundary/*.hcl
sudo chmod 640 /etc/boundary/*.hcl

# Buat layanan systemd (controller)
cat > /etc/systemd/system/boundary-controller.service <<'EOF'
[Unit]
Description=HashiCorp Boundary Controller
After=network-online.target
Wants=network-online.target
[Service]
Type=notify
User=boundary
Group=boundary
ExecStart=/usr/local/bin/boundary server -config=/etc/boundary/controller.hcl
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF

# Buat layanan systemd (worker)
cat > /etc/systemd/system/boundary-worker.service <<'EOF'
[Unit]
Description=HashiCorp Boundary Worker
After=boundary-controller.service
Requires=boundary-controller.service
[Service]
Type=notify
User=boundary
Group=boundary
ExecStart=/usr/local/bin/boundary server -config=/etc/boundary/worker.hcl
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF

# Mulai layanan
echo "Memulai layanan Boundary..."
sudo systemctl daemon-reload
sudo -u boundary /usr/local/bin/boundary database init -config /etc/boundary/controller.hcl || echo "Database kemungkinan sudah diinisialisasi."
sudo systemctl enable --now boundary-controller
sudo systemctl enable --now boundary-worker

sleep 10
echo "=========================================="
echo "Instalasi Selesai. Status Layanan:"
sudo systemctl status boundary-controller --no-pager | head -5
sudo systemctl status boundary-worker --no-pager | head -5
echo "=========================================="
