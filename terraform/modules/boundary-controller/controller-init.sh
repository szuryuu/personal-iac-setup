#!/bin/bash
set -e

# Update system
apt-get update
apt-get install -y curl unzip

# Install Boundary worker
BOUNDARY_VERSION="0.19.3"
curl -fsSL https://releases.hashicorp.com/boundary/${BOUNDARY_VERSION}/boundary_${BOUNDARY_VERSION}_linux_amd64.zip -o boundary.zip
unzip boundary.zip
sudo mv boundary /usr/local/bin/
rm boundary.zip

# Create boundary user and directories
sudo useradd --system --home /etc/boundary --shell /bin/false boundary
sudo mkdir -p /etc/boundary /opt/boundary/data
sudo chown -R boundary:boundary /etc/boundary /opt/boundary

cat > /etc/boundary/controller.hcl <<EOF
disable_mlock = true

controller {
  name        = "controller-${environment}"
  description = "Controller untuk ${environment} environment."
}

listener "tcp" {
  address = "0.0.0.0:9201"
  purpose = "api"
}

listener "tcp" {
  address = "0.0.0.0:9200"
  purpose = "cluster"
}

database {
  url = "${db_connection_string}"
}

kms "aead" {
  purpose    = "root"
  aead_type  = "aes-gcm"
  key        = "base64encodedkey"
  key_id     = "global_root"
}

kms "aead" {
  purpose    = "worker-auth"
  aead_type  = "aes-gcm"
  key        = "base64encodedkey"
  key_id     = "worker_auth"
}

kms "aead" {
  purpose    = "recovery"
  aead_type  = "aes-gcm"
  key        = "base64encodedkey"
  key_id     = "recovery"
}

log {
  level = "info"
  format = "standard"
  output = "stdout"
}
EOF

sudo chown boundary:boundary /etc/boundary/controller.hcl
sudo chmod 640 /etc/boundary/controller.hcl

# Create systemd service
cat > /etc/systemd/system/boundary-controller.service <<EOF
[Unit]
Description=HashiCorp Boundary Controller
After=network.target

[Service]
User=boundary
Group=boundary
ExecStart=/usr/local/bin/boundary server -config=/etc/boundary/controller.hcl
Restart=on-failure
LimitMEMLOCK=infinity
AmbientCapabilities=CAP_IPC_LOCK

[Install]
WantedBy=multi-user.target
EOF

# Start and enable the service
sudo systemctl daemon-reload
sudo systemctl enable boundary-controller
sudo systemctl start boundary-controller
