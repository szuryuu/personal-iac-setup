#!/bin/bash
set -e

apt-get update
apt-get install -y curl unzip

BOUNDARY_VERSION="0.19.3"
curl -fsSL https://releases.hashicorp.com/boundary/${BOUNDARY_VERSION}/boundary_${BOUNDARY_VERSION}_linux_amd64.zip -o boundary.zip
unzip boundary.zip
sudo mv boundary /usr/local/bin/
rm boundary.zip

sudo useradd --system --home /etc/boundary --shell /bin/false boundary || true
sudo mkdir -p /etc/boundary /opt/boundary/data
sudo chown -R boundary:boundary /etc/boundary /opt/boundary

cat > /etc/boundary/worker.hcl <<EOF
disable_mlock = true

worker {
  name        = "azure-worker-$(hostname)"
  description = "Azure Boundary worker"
  controllers = ["${boundary_cluster_url}:9201"]

  public_addr = "$(curl -H Metadata:true --noproxy "*" \
    "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2021-02-01&format=text")"
}

listener "tcp" {
  address = "0.0.0.0:9202"
  purpose = "proxy"
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
  output = "stdout"
}
EOF

sudo chown boundary:boundary /etc/boundary/worker.hcl
sudo chmod 640 /etc/boundary/worker.hcl

cat > /etc/systemd/system/boundary-worker.service <<EOF
[Unit]
Description=Boundary Worker
After=network-online.target
Requires=network-online.target

[Service]
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
sudo systemctl enable boundary-worker
sudo systemctl start boundary-worker
