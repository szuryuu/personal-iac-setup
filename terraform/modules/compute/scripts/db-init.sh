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

echo "Create Database"

mysql -u root -p${db_password} -e "CREATE DATABASE ${db_name};"

echo "Create User"
mysql -u root -p${db_password} -e "CREATE USER '${db_username}'@'%' IDENTIFIED BY '${db_password}';"

echo "Grant Privileges"
mysql -u root -p${db_password} -e "GRANT ALL PRIVILEGES ON ${db_username}.* TO '${db_username}'@'%';"

echo "Flush Privileges"
mysql -u root -p${db_password} -e "FLUSH PRIVILEGES;"

echo "MySQL Setup Completed"
