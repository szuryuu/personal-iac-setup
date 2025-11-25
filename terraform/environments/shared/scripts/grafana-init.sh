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
sudo apt-get install grafana

# Start grafana
echo "[+] Enabling and starting Grafana service..."
systemctl enable grafana-server
systemctl start grafana-server

echo "[+] Checking Grafana status..."
systemctl status grafana-server --no-pager || true
