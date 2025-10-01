# Azure
resource_group_name = "devops-intern-sandbox-rg-sandbox-sea"
subscription_id     = "ff2d14b3-1df7-4fb7-9440-963a479f8079"
key_vault_name      = "rg-intern-devops"

# Environment variables
environment           = "dev"
project_name          = "dev-area"
vm_size               = "Standard_B1s"
db_sku_name           = "B_Standard_B1ms"
backup_retention_days = 7

# Network variables - Dual Database Setup
vnet_cidr              = "10.1.0.0/16"
vm_subnet_cidr         = "10.1.1.0/24"
mysql_subnet_cidr      = "10.1.2.0/24" # untuk aplikasi
postgresql_subnet_cidr = "10.1.3.0/24" # untuk Boundary
boundary_subnet_cidr   = "10.1.4.0/24" # untuk Boundary VM
boundary_cluster_url   = "10.1.4.0:9200"
