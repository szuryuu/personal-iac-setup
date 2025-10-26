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

MYSQL_PASSWORD=${db_password}
MYSQL_USER=${db_username}

echo "Create Database"
mysql -u root -p${MYSQL_PASSWORD} -e "CREATE DATABASE ${db_name};"

echo "Create User"
mysql -u root -p${MYSQL_PASSWORD} -e "CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';"

echo "Grant Privileges"
mysql -u root -p${MYSQL_PASSWORD} -e "GRANT ALL PRIVILEGES ON ${db_name}.* TO '${MYSQL_USER}'@'%';"

echo "Flush Privileges"
mysql -u root -p${MYSQL_PASSWORD} -e "FLUSH PRIVILEGES;"

echo "MySQL Setup Completed"
