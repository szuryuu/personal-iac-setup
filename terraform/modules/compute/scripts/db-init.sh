#!/bin/bash
set -euo pipefail

exec > >(tee /var/log/db-install.log)
exec 2>&1

echo "Update"
sudo apt-get update -y

echo "Install MySQL Server"
sudo DEBIAN_FRONTEND=noninteractive apt install -y mysql-server

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
FLUSH PRIVILEGES;
EOF

echo "Restart MySQL"
sudo systemctl restart mysql
