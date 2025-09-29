#!/bin/bash
set -e

# Update system
apt-get update
apt-get install -y curl unzip mysql-client

# Install Boundary worker
curl -fsSL https://releases.hashicorp.com/boundary/${BOUNDARY_VERSION}/boundary_${BOUNDARY_VERSION}_linux_amd64.zip -o boundary.zip
unzip boundary.zip
sudo mv boundary /usr/local/bin/
rm boundary.zip

# Create boundary user and directories
sudo useradd --system --home /etc/boundary --shell /bin/false boundary
sudo mkdir -p /etc/boundary /opt/boundary/data
sudo chown -R boundary:boundary /etc/boundary /opt/boundary

ROOT_KEY=$(openssl rand -base64 32)
# WORKER_AUTH_KEY=$(openssl rand -base64 32)
RECOVERY_KEY=$(openssl rand -base64 32)

PUBLIC_IP=$(curl -H Metadata:true --noproxy "*" \
  "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2021-02-01&format=text" 2>/dev/null || echo "127.0.0.1")

# --- Controller config ---
cat > /etc/boundary/controller.hcl <<EOF
disable_mlock = true

controller {
  name        = "controller-${environment}"
  description = "Controller untuk ${environment} environment"
}

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
  key        = "$ROOT_KEY"
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
  key        = "$RECOVERY_KEY"
  key_id     = "recovery"
}

log {
  level = "info"
  format = "standard"
}
EOF

sudo chown boundary:boundary /etc/boundary/controller.hcl
sudo chmod 640 /etc/boundary/controller.hcl

# --- Worker config ---
cat > /etc/boundary/worker.hcl <<EOF
disable_mlock = true

worker {
  name        = "azure-worker-$(hostname)"
  description = "Azure Boundary worker"
  controllers = ["127.0.0.1:9201"]
  public_addr = "$PUBLIC_IP"
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
EOF

sudo chown boundary:boundary /etc/boundary/worker.hcl
sudo chmod 640 /etc/boundary/worker.hcl

# --- systemd service: controller ---
cat > /etc/systemd/system/boundary-controller.service <<EOF
[Unit]
Description=HashiCorp Boundary Controller
After=network.target
Before=boundary-worker.service

[Service]
Type=notify
User=boundary
Group=boundary
ExecStart=/usr/local/bin/boundary server -config=/etc/boundary/controller.hcl
Restart=on-failure
LimitMEMLOCK=infinity
AmbientCapabilities=CAP_IPC_LOCK

[Install]
WantedBy=multi-user.target
EOF

# --- systemd service: worker ---
cat > /etc/systemd/system/boundary-worker.service <<EOF
[Unit]
Description=HashiCorp Boundary Worker
After=network-online.target boundary-controller.service
Requires=network-online.target boundary-controller.service

[Service]
Type=notify
User=boundary
Group=boundary
ExecStart=/usr/local/bin/boundary server -config=/etc/boundary/worker.hcl
Restart=on-failure
LimitMEMLOCK=infinity
AmbientCapabilities=CAP_IPC_LOCK

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload

sleep 30

sudo -u boundary /usr/local/bin/boundary database init -config=/etc/boundary/controller.hcl || echo "Database already initialized"

sudo systemctl enable boundary-controller
sudo systemctl start boundary-controller

sleep 15

sudo systemctl enable boundary-worker
sudo systemctl start boundary-worker

sleep 10
