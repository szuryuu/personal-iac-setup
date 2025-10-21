terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

data "azurerm_key_vault" "existing" {
  name                = var.key_vault_name
  resource_group_name = var.resource_group_name
}

data "azurerm_key_vault_secret" "ssh_public_key" {
  name         = "${var.environment}-vm-ssh-public-keys"
  key_vault_id = data.azurerm_key_vault.existing.id
}

data "azurerm_key_vault_secret" "db_password" {
  name         = "${var.environment}-db-password-login-creds"
  key_vault_id = data.azurerm_key_vault.existing.id
}

data "azurerm_key_vault_secret" "db_username" {
  name         = "${var.environment}-db-username-login-creds"
  key_vault_id = data.azurerm_key_vault.existing.id
}

# NETWORK MODULE
module "network" {
  source              = "../../modules/network"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location

  # Network Configuration
  vnet_cidr               = var.vnet_cidr
  vm_subnet_cidr          = var.vm_subnet_cidr
  mysql_subnet_cidr       = var.mysql_subnet_cidr
  postgresql_subnet_cidr  = var.postgresql_subnet_cidr
  boundary_subnet_cidr    = var.boundary_subnet_cidr
  semaphore_subnet_cidr   = var.semaphore_subnet_cidr
  create_private_dns_zone = true

  is_terratest = var.is_terratest
  environment  = var.environment
}

# COMPUTE MODULE
module "compute" {
  source              = "../../modules/compute"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  vm_size             = var.vm_size

  network_interface_ids = module.network.nic_ids
  ssh_public_key        = data.azurerm_key_vault_secret.ssh_public_key.value

  environment  = var.environment
  project_name = var.project_name

  depends_on = [module.network]
}

# DATABASE MODULE (MySQL + PostgreSQL)
module "database" {
  source              = "../../modules/database"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location

  # Database credentials
  db_admin_login          = data.azurerm_key_vault_secret.db_username.value
  db_admin_login_password = data.azurerm_key_vault_secret.db_password.value
  db_sku_name             = var.db_sku_name
  backup_retention_days   = var.backup_retention_days

  # MySQL Network configuration
  mysql_delegated_subnet_id   = module.network.mysql_subnet_id
  mysql_private_dns_zone_id   = module.network.mysql_private_dns_zone_id
  mysql_private_dns_zone_link = module.network.mysql_private_dns_zone_link

  # PostgreSQL Network configuration
  postgresql_delegated_subnet_id   = module.network.postgresql_subnet_id
  postgresql_private_dns_zone_id   = module.network.postgresql_private_dns_zone_id
  postgresql_private_dns_zone_link = module.network.postgresql_private_dns_zone_link

  environment  = var.environment
  project_name = var.project_name

  depends_on = [
    module.network,
    module.network.mysql_subnet_id,
    module.network.mysql_private_dns_zone_id,
    module.network.mysql_private_dns_zone_link,
    module.network.postgresql_subnet_id,
    module.network.postgresql_private_dns_zone_id,
    module.network.postgresql_private_dns_zone_link
  ]
}

# BOUNDARY MODULE
module "boundary" {
  source              = "../../modules/boundary"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  vm_size             = var.boundary_vm_size

  # Network configuration
  boundary_subnet_id = module.network.boundary_subnet_id

  # PostgreSQL Database (for Boundary)
  db_host     = module.database.postgresql_fqdn
  db_username = data.azurerm_key_vault_secret.db_username.value
  db_password = data.azurerm_key_vault_secret.db_password.value

  # SSH public key
  ssh_public_key = data.azurerm_key_vault_secret.ssh_public_key.value

  environment  = var.environment
  project_name = var.project_name

  depends_on = [
    module.network,
    module.database
  ]
}

# SEMAPHORE MODULE
module "semaphore" {
  source              = "../../modules/semaphore"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  vm_size             = var.semaphore_vm_size

  # Network configuration
  semaphore_subnet_id = module.network.semaphore_subnet_id

  # SSH public key
  ssh_public_key = data.azurerm_key_vault_secret.ssh_public_key.value

  environment  = var.environment
  project_name = var.project_name

  depends_on = [
    module.network,
    module.database
  ]
}
