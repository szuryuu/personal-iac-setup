#!/bin/bash
set -euo pipefail

exec > >(tee /var/log/tools-install.log)
exec 2>&1

echo "=========================================="
echo "Tools Installation - $(date)"
echo "=========================================="

# Update system
echo "[+] Updating system..."
apt-get update -y
apt-get upgrade -y

# Install Docker
echo "[+] Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
systemctl enable docker
systemctl start docker
usermod -aG docker adminuser

# Install Docker Compose
echo "[+] Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Setup data disk
echo "[+] Setting up data disk..."
mkdir -p /mnt/semaphore-data/{db,ssh,ansible}
mkdir -p /mnt/liquibase-data/{scripts,changelog}
chown -R 1001:1001 /mnt/semaphore-data

# Setup SSH key
echo "[+] Setting up SSH keys..."
cat > /mnt/semaphore-data/ssh/id_rsa << 'EOF'
${ssh_private_key}
EOF
chown 1001:1001 /mnt/semaphore-data/ssh/id_rsa
chmod 600 /mnt/semaphore-data/ssh/id_rsa

# Setup Liquibase changelog
echo "[+] Setting up Liquibase changelog..."
cat > /mnt/liquibase-data/changelog/changelog.xml << 'CHANGELOG_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog
    xmlns="http://www.liquibase.org/xml/ns/dbchangelog"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog
    http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-4.20.xsd">

    <property name="liquibase.percona.defaultOn" value="true"/>
    <property name="liquibase.percona.skipChanges" value=""/>
    <property name="liquibase.percona.failIfNoPT" value="false"/>
    <property name="liquibase.percona.noAlterSqlDryMode" value="false"/>
    <property name="liquibase.percona.ptOnlineSchemaChangePath" value="/usr/bin/pt-online-schema-change"/>
    <property name="liquibase.percona.options" value="--alter-foreign-keys-method=auto --max-load=Threads_running=100"/>

    <changeSet id="1" author="admin">
        <comment>Initial setup</comment>
        <createTable tableName="sample_table">
            <column name="id" type="INT" autoIncrement="true">
                <constraints primaryKey="true" nullable="false"/>
            </column>
            <column name="name" type="VARCHAR(255)">
                <constraints nullable="false"/>
            </column>
            <column name="created_at" type="TIMESTAMP" defaultValueComputed="CURRENT_TIMESTAMP"/>
        </createTable>
    </changeSet>

    <changeSet id="2" author="admin">
        <comment>Tambah tabel coba</comment>
        <createTable tableName="coba">
            <column name="id" type="INT" autoIncrement="true">
                <constraints primaryKey="true" nullable="false"/>
            </column>
            <column name="deskripsi" type="VARCHAR(255)">
                <constraints nullable="false"/>
            </column>
            <column name="created_at" type="TIMESTAMP" defaultValueComputed="CURRENT_TIMESTAMP"/>
        </createTable>
    </changeSet>

    <changeSet id="3" author="admin">
        <comment>Add email column using Percona online migration</comment>
        <addColumn tableName="sample_table">
            <column name="email" type="VARCHAR(255)"/>
        </addColumn>
    </changeSet>

</databaseChangeLog>
CHANGELOG_EOF

cat > /mnt/liquibase-data/liquibase.properties << 'PROPS_EOF'
changeLogFile=changelog/changelog.xml
driver=com.mysql.cj.jdbc.Driver
PROPS_EOF

# Setup SSH config
echo "[+] Setting up SSH config..."
cat > /mnt/semaphore-data/ssh/config << 'EOF'
# DEV ENVIRONMENT
Host dev-boundary
  HostName ${dev_boundary_ip}
  User adminuser
  IdentityFile /etc/semaphore/id_rsa
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null

Host dev-vm
  HostName ${dev_vm_ip}
  User adminuser
  IdentityFile /etc/semaphore/id_rsa
  ProxyJump dev-boundary
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null

# STAGING ENVIRONMENT
Host staging-boundary
  HostName ${staging_boundary_ip}
  User adminuser
  IdentityFile /etc/semaphore/id_rsa
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null

Host staging-vm
  HostName ${staging_vm_ip}
  User adminuser
  IdentityFile /etc/semaphore/id_rsa
  ProxyJump staging-boundary
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null

# PROD ENVIRONMENT
Host prod-boundary
  HostName ${prod_boundary_ip}
  User adminuser
  IdentityFile /etc/semaphore/id_rsa
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null

Host prod-vm
  HostName ${prod_vm_ip}
  User adminuser
  IdentityFile /etc/semaphore/id_rsa
  ProxyJump prod-boundary
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null

EOF
chown 1001:1001 /mnt/semaphore-data/ssh/config
chmod 644 /mnt/semaphore-data/ssh/config

# Clone Ansible repo
echo "[+] Cloning Ansible repository..."
if [ ! -z "${ansible_repo_url}" ]; then
    git clone ${ansible_repo_url} /mnt/semaphore-data/piac
    chown -R 1001:1001 /mnt/semaphore-data/piac/ansible
fi

echo "[+] Downloading MySQL JDBC Driver..."
mkdir -p /mnt/liquibase-data/lib
curl -L "https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/8.0.33/mysql-connector-j-8.0.33.jar" -o /mnt/liquibase-data/lib/mysql-connector-java.jar

# Percona Extension
wget https://github.com/liquibase/liquibase-percona/releases/download/v4.33.0/liquibase-percona-4.33.0.jar -O /mnt/liquibase-data/lib/liquibase-percona.jar

# Add Dockerfile
echo "[+] Adding Dockerfile..."
cat > /mnt/liquibase-data/Dockerfile << 'EOF'
FROM liquibase/liquibase:4.33.0

USER root
RUN apt-get update && apt-get install -y percona-toolkit && rm -rf /var/lib/apt/lists/*
USER liquibase
EOF

# Setup Docker Compose
echo "[+] Setting up Semaphore with Docker Compose..."
cat > /home/adminuser/docker-compose.yml << 'EOF'
services:
    semaphore:
        image: semaphoreui/semaphore:latest
        container_name: semaphore
        restart: unless-stopped
        ports:
            - "3000:3000"
        environment:
            SEMAPHORE_DB_DIALECT: ${db_dialect}
            SEMAPHORE_ADMIN: admin
            SEMAPHORE_ADMIN_PASSWORD: ${admin_password}
            SEMAPHORE_ADMIN_NAME: Admin
            SEMAPHORE_ADMIN_EMAIL: admin@localhost
            ANSIBLE_LOCAL_TEMP: /tmp
            SEMAPHORE_TMP_PATH: /tmp
            ANSIBLE_GALAXY_CACHE_DIR: /tmp
            ANSIBLE_GALAXY_SERVER_CACHE_PATH: /tmp
        volumes:
            - /mnt/semaphore-data/db:/tmp/semaphore
            - /mnt/semaphore-data/piac/ansible:/ansible
            - /mnt/semaphore-data/ssh/id_rsa:/etc/semaphore/id_rsa:ro
            - /mnt/semaphore-data/ssh/config:/etc/semaphore/ssh_config:ro
        networks:
            - tools-net

    liquibase:
        build: /mnt/liquibase-data
        container_name: liquibase
        restart: unless-stopped
        init: true
        environment:
            LIQUIBASE_COMMAND_URL: jdbc:mysql://${dev_vm_ip}:3306/mydatabase
            LIQUIBASE_COMMAND_USERNAME: ${db_username}
            LIQUIBASE_COMMAND_PASSWORD: ${db_password}
        volumes:
            - /mnt/liquibase-data/liquibase.properties:/liquibase/liquibase.properties
            - /mnt/liquibase-data/changelog:/liquibase/changelog
            - /mnt/liquibase-data/lib/mysql-connector-java.jar:/liquibase/lib/mysql-connector-java.jar
            - /mnt/liquibase-data/lib/liquibase-percona.jar:/liquibase/lib/liquibase-percona.jar
        command: ["sleep", "infinity"]
        networks:
            - tools-net

    # bytebase:
    #     image: bytebase/bytebase:latest
    #     container_name: bytebase
    #     restart: unless-stopped
    #     init: true
    #     ports:
    #         - "8080:8080"
    #     environment:
    #         BB_LOG_LEVEL: info
    #     volumes:
    #         - /home/adminuser/.bytebase/data:/var/opt/bytebase
    #     networks:
    #         - tools-net

networks:
    tools-net:
        driver: bridge

EOF

chown adminuser:adminuser /home/adminuser/docker-compose.yml

# Start Tools...
echo "Starting Tools..."
cd /home/adminuser
docker-compose up -d

echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo "Semaphore URL: http://$(curl -s ifconfig.me):3000"
echo "Username: admin"
echo "Password: ${admin_password}"
echo ""
echo "Environments configured:"
echo "  - DEV: ${dev_vm_ip} (via ${dev_boundary_ip})"
echo "  - STAGING: ${staging_vm_ip} (via ${staging_boundary_ip})"
echo "  - PROD: ${prod_vm_ip} (via ${prod_boundary_ip})"
echo ""
echo "Bytebase URL: http://$(curl -s ifconfig.me):8080"
echo "=========================================="
