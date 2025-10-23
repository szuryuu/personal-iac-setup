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
