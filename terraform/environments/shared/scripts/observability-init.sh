#!/bin/bash
set -euo pipefail

exec > >(tee /var/log/grafana-init.log)
exec 2>&1

echo "=========================================="
echo "Grafana Installation - $(date)"
echo "=========================================="

# Update packages
echo "[+] Updating packages"
apt-get update -y

echo "[+] Preparing system"
# Install the prerequisite packages
sudo apt-get install -y apt-transport-https software-properties-common wget

# Import the GPG key
sudo mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null

# Add stable repository
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list

# Update packages
echo "[+] Updating packages"
apt-get update -y

# Installing grafana
echo "[+] Installing grafana"
sudo apt-get install grafana -y

# Start grafana
echo "[+] Enabling and starting Grafana service..."
systemctl enable grafana-server
systemctl start grafana-server

echo "[+] Checking Grafana status..."
systemctl status grafana-server --no-pager || true

# Installing prometheus
echo "[+] Installing prometheus"
wget https://github.com/prometheus/prometheus/releases/download/v3.7.3/prometheus-3.7.3.linux-amd64.tar.gz
tar xvf prometheus-3.7.3.linux-amd64.tar.gz
sudo mv prometheus-3.7.3.linux-amd64 /opt/prometheus

# Prometheus config
cat > /opt/prometheus/prometheus.yml <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'dev-vm'
    static_configs:
      - targets: ['${dev_private_ip}:9100']
        labels:
          environment: 'dev'

  - job_name: 'staging-vm'
    static_configs:
      - targets: ['${staging_private_ip}:9100']
        labels:
          environment: 'staging'

  - job_name: 'prod-vm'
    static_configs:
      - targets: ['${prod_private_ip}:9100']
        labels:
          environment: 'prod'
EOF

# Create systemd service
sudo tee /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus
After=network.target

[Service]
Type=simple
ExecStart=/opt/prometheus/prometheus --config.file=/opt/prometheus/prometheus.yml --storage.tsdb.path=/opt/prometheus/data

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus
