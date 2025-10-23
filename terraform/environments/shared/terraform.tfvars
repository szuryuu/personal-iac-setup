# Azure
resource_group_name = "devops-intern-sandbox-rg-sandbox-sea"
subscription_id     = "ff2d14b3-1df7-4fb7-9440-963a479f8079"
key_vault_name      = "rg-intern-devops"

# Network Configuration
shared_vnet_cidr       = "10.100.0.0/16"
tool_subnet_cidr  = "10.100.1.0/24"
boundary_subnet_cidr   = "10.100.3.0/24"

# VM Configuration
vm_size = "Standard_B2s"

tool_admin_password = "changeme"
