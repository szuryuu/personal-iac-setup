#!/bin/bash
set -e

# Update system
apt-get update
apt-get install -y curl unzip

# Install Boundary worker
BOUNDARY_VERSION="0.17.0"
curl -fsSL https://releases.hashicorp.com/boundary/${BOUNDARY_VERSION}/boundary_${BOUNDARY_VERSION}_linux_amd64.zip -o boundary.zip
unzip boundary.zip
sudo mv boundary /usr/local/bin/
rm boundary.zip

# Create boundary user and directories
sudo useradd --system --home /etc/boundary --shell /bin/false boundary
sudo mkdir -p /etc/boundary /opt/boundary/data
sudo chown -R boundary:boundary /etc/boundary /opt/boundary

# Create boundary worker configuration
cat > /etc/boundary/worker.hcl <<EOF
disable_mlock = true

hcp_boundary_cluster_id = "$(echo '${boundary_cluster_url}' | sed 's|https://||' | cut -d'.' -f1)"

worker {
  name = "azure-worker-$(hostname)"
  description = "Azure Boundary worker"
  controllers = ["${boundary_cluster_url}"]

  public_addr = "$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
}

listener "tcp" {
  address = "0.0.0.0:9202"
  purpose = "proxy"
}

kms "aead" {
  purpose = "worker-auth"
  aead_type = "aes-gcm"
  key = "$(openssl rand -base64 32)"
  key_id = "worker-auth"
}
EOF

# Create systemd service
cat > /etc/systemd/system/boundary-worker.service <<EOF
[Unit]
Description=Boundary Worker
Documentation=https://www.boundaryproject.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/boundary/worker.hcl

[Service]
Type=notify
ExecStart=/usr/local/bin/boundary server -config=/etc/boundary/worker.hcl
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536
User=boundary
Group=boundary

[Install]
WantedBy=multi-user.target
EOF

# Start and enable the service
sudo systemctl daemon-reload
sudo systemctl enable boundary-worker
sudo systemctl start boundary-worker
