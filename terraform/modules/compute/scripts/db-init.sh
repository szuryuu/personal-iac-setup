#!/bin/bash
set -euo pipefail

exec > >(tee /var/log/db-install.log)
exec 2>&1

# Update
sudo apt-get update -y

# ProxySQL Key
apt-get install -y --no-install-recommends lsb-release wget apt-transport-https ca-certificates gnupg
wget -O - 'https://repo.proxysql.com/ProxySQL/proxysql-3.0.x/repo_pub_key' | apt-key add -
echo deb https://repo.proxysql.com/ProxySQL/proxysql-3.0.x/$(lsb_release -sc)/ ./ | tee /etc/apt/sources.list.d/proxysql.list

# Update
# TERM=xterm sudo nano /etc/proxysql.cnf
sudo apt-get update -y

echo "Installing some tools"
sudo DEBIAN_FRONTEND=noninteractive apt install -y mysql-server proxysql

sudo systemctl enable mysql
sudo systemctl start mysql

echo "Configure MySQL to listen on all interfaces"
sudo sed -i 's/bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf

echo "Set root password and create database"
mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${db_password}';
FLUSH PRIVILEGES;

CREATE DATABASE IF NOT EXISTS ${db_name};
CREATE USER IF NOT EXISTS '${db_username}'@'%' IDENTIFIED BY '${db_password}';
GRANT ALL PRIVILEGES ON *.* TO '${db_username}'@'%' WITH GRANT OPTION;

CREATE USER IF NOT EXISTS '${db_username}'@'127.0.0.1' IDENTIFIED BY '${db_password}';
GRANT ALL PRIVILEGES ON *.* TO '${db_username}'@'127.0.0.1' WITH GRANT OPTION;

CREATE USER IF NOT EXISTS 'monitor'@'%' IDENTIFIED BY 'monitor';
GRANT USAGE, REPLICATION CLIENT ON *.* TO 'monitor'@'%';

FLUSH PRIVILEGES;
EOF

echo "Restart MySQL"
sudo systemctl restart mysql

echo "ProxySQL Setup"
sudo systemctl start proxysql
sudo systemctl enable proxysql
sudo systemctl restart proxysql

service proxysql initial
proxysql --version
