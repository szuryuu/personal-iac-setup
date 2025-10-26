#!/bin/bash
set -euo pipefail

exec > >(tee /var/log/boundary-init.log)
exec 2>&1

echo "=========================================="
echo "Boundary Installation - $(date)"
echo "=========================================="

# Update System and install PostgreSQL client
echo "[+] Updating packages and installing utilities..."
apt-get update -y
apt-get install -y curl unzip postgresql-client jq

echo "[+] Installing PostgreSQL Server..."
apt-get install -y postgresql postgresql-contrib
systemctl enable postgresql
systemctl start postgresql

echo "[+] Configuring PostgreSQL for Boundary..."
BOUNDARY_DB_PASSWORD="${db_password}"
sudo -u postgres psql <<EOF
CREATE DATABASE boundary;
CREATE USER boundary WITH PASSWORD '$BOUNDARY_DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE boundary TO boundary;
\q
EOF

# Install Boundary
echo "[+] Installing Boundary version ${BOUNDARY_VERSION}..."
curl -fsSL https://releases.hashicorp.com/boundary/${BOUNDARY_VERSION}/boundary_${BOUNDARY_VERSION}_linux_amd64.zip -o boundary.zip
unzip -o boundary.zip
sudo mv boundary /usr/local/bin/
rm boundary.zip

boundary version

# Make user and directory for Boundary
echo "[+] Creating user and directory for Boundary..."
sudo useradd --system --home /etc/boundary --shell /bin/false boundary || true
sudo mkdir -p /etc/boundary /opt/boundary/data
sudo chown -R boundary:boundary /etc/boundary /opt/boundary

# Generate encryption keys
echo "[+] Generating encryption keys..."
ROOT_KEY=$(openssl rand -base64 32)
RECOVERY_KEY=$(openssl rand -base64 32)

# Get public IP
PUBLIC_IP=$(curl -s -H "Metadata:true" \
  "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2021-02-01&format=text")

if [ -z "$PUBLIC_IP" ]; then
  PUBLIC_IP=$(curl -s ifconfig.me)
fi

echo "Public IP: $PUBLIC_IP"

# Create configuration file
echo "[+] Creating configuration file..."

# PostgreSQL connection string
DB_URL="postgresql://boundary:${encoded_db_password}@localhost:5432/boundary?sslmode=disable"
echo "DB URL (masked): postgresql://boundary:***@localhost:5432/boundary?sslmode=disable"

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
Type=exec
User=boundary
Group=boundary
ExecStart=/usr/local/bin/boundary server -config=/etc/boundary/controller.hcl
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStartSec=900
TimeoutStopSec=30
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
CONTROLLER_SERVICE

cat > /etc/systemd/system/boundary-worker.service << 'WORKER_SERVICE'
[Unit]
Description=HashiCorp Boundary Worker
After=network-online.target
Wants=network-online.target

[Service]
Type=exec
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

# Initialize database and capture output
echo "=========================================="
echo "Initializing Boundary database..."
DB_INIT_OUTPUT=$(sudo -u boundary /usr/local/bin/boundary database init -config /etc/boundary/controller.hcl || echo "Database init warning (might already be initialized)")
echo "$DB_INIT_OUTPUT"

# Extract credentials from output if init was successful
INITIAL_AUTH_METHOD_ID=""
INITIAL_PASSWORD=""
if [[ "$DB_INIT_OUTPUT" != *"Database init warning"* ]]; then
    INITIAL_AUTH_METHOD_ID=$(echo "$DB_INIT_OUTPUT" | grep 'Auth Method ID:' | awk '{$1=$2=$3=""; print $0}' | xargs)
    INITIAL_PASSWORD=$(echo "$DB_INIT_OUTPUT" | grep 'Password:' | awk '{$1=""; print $0}' | xargs)
    echo "Extracted Auth Method ID: $INITIAL_AUTH_METHOD_ID"
    # Do not echo password for security
else
    echo "Skipping credential extraction as database might be already initialized."
fi


# Start services
echo "Starting Boundary services..."
sudo systemctl enable boundary-controller
sudo systemctl start boundary-controller

sleep 20 # Give controller time to start

sudo systemctl enable boundary-worker
sudo systemctl start boundary-worker

sleep 15 # Give worker time to start

# Configure Boundary Resources (only if init was successful and creds were extracted)
DEV_TARGET_ID="N/A"
STAGING_TARGET_ID="N/A"
PROD_TARGET_ID="N/A"

if [[ -n "$INITIAL_AUTH_METHOD_ID" && -n "$INITIAL_PASSWORD" ]]; then
    echo "[+] Authenticating to Boundary..."
    export BOUNDARY_ADDR="http://127.0.0.1:9200"
    echo "$INITIAL_PASSWORD" | boundary authenticate password \
      -auth-method-id="$INITIAL_AUTH_METHOD_ID" \
      -login-name=admin

    if [ $? -eq 0 ]; then
        echo "[+] Authentication successful. Creating resources..."
        echo "[+] Creating Organization..."
        ORG_ID=$(boundary scopes create \
          -scope-id=global \
          -name="devops-org" \
          -description="DevOps Organization" \
          -format=json | jq -r '.item.id')

        echo "[+] Creating Project..."
        PROJECT_ID=$(boundary scopes create \
          -scope-id=$ORG_ID \
          -name="azure-infrastructure" \
          -description="Azure VMs" \
          -format=json | jq -r '.item.id')

        echo "[+] Creating Host Catalog..."
        CATALOG_ID=$(boundary host-catalogs create static \
          -scope-id=$PROJECT_ID \
          -name="azure-vms" \
          -format=json | jq -r '.item.id')

        setup_env() {
          local ENV=$1
          local IP=$2
          local TARGET_VAR_NAME=$3

          echo "[+] Setting up $ENV environment..."

          if [ -z "$IP" ]; then
            echo "Warning: IP Address for $ENV is empty. Skipping Host/Target creation."
            eval $TARGET_VAR_NAME="IP_MISSING"
            return
          fi

          local HOST_ID
          HOST_ID=$(boundary hosts create static \
            -host-catalog-id=$CATALOG_ID \
            -name="${ENV}-vm" \
            -address="$IP" \
            -format=json | jq -r '.item.id')

          local SET_ID
          SET_ID=$(boundary host-sets create static \
            -host-catalog-id=$CATALOG_ID \
            -name="${ENV}-hosts" \
            -format=json | jq -r '.item.id')

          boundary host-sets add-hosts \
            -id=$SET_ID \
            -host=$HOST_ID > /dev/null

          local TARGET_ID
          TARGET_ID=$(boundary targets create tcp \
            -scope-id=$PROJECT_ID \
            -name="${ENV}-vm-ssh" \
            -description="SSH to ${ENV^^} VM" \
            -default-port=22 \
            -session-connection-limit=-1 \
            -format=json | jq -r '.item.id')

          boundary targets add-host-sources \
            -id=$TARGET_ID \
            -host-source=$SET_ID > /dev/null

          # Store the target ID in the specified variable
          eval $TARGET_VAR_NAME="$TARGET_ID"
          echo "$ENV Target ID captured: ${!TARGET_VAR_NAME}"
        }

        # Use different variable names for each target ID
        setup_env "dev" "${dev_ip}" "DEV_TARGET_ID"
        # setup_env "staging" "${staging_ip}" "STAGING_TARGET_ID"
        # setup_env "prod" "${prod_ip}" "PROD_TARGET_ID"

    else
        echo "Error: Boundary authentication failed. Skipping resource creation."
    fi
else
    echo "Warning: Could not extract initial credentials or database already initialized. Skipping resource creation."
fi


echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo "Controller API: http://$PUBLIC_IP:9200"
echo "Worker Proxy: $PUBLIC_IP:9202"
echo ""
echo "Boundary Info (Target IDs might require manual check if script rerun):"
echo "  DEV Target ID:     $DEV_TARGET_ID"
echo "  STAGING Target ID: $STAGING_TARGET_ID"
echo "  PROD Target ID:    $PROD_TARGET_ID"
echo ""
systemctl status boundary-controller --no-pager -l | head -10
systemctl status boundary-worker --no-pager -l | head -10
echo "=========================================="
