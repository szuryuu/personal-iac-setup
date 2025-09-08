terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"
    }
  }
}

provider "azurerm" {
  features {
  }

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
  name         = "vm-ssh-public-key"
  key_vault_id = data.azurerm_key_vault.existing.id
}

# resource "azurerm_resource_group" "main" {
#   name     = "sz-the-devops"
#   location = "Southeast Asia"
# }

module "compute" {
  source                = "./modules/compute"
  resource_group_name   = data.azurerm_resource_group.main.name
  location              = data.azurerm_resource_group.main.location
  network_interface_ids = module.network.nic_ids
  ssh_public_key        = data.azurerm_key_vault_secret.ssh_public_key.value
}

module "database" {
  source                  = "./modules/database"
  resource_group_name     = data.azurerm_resource_group.main.name
  location                = data.azurerm_resource_group.main.location
  db_admin_login          = var.db_admin_login
  db_admin_login_password = var.db_admin_login_password
  start_ip_address        = module.network.public_ip_address
  end_ip_address          = module.network.public_ip_address
  delegated_subnet_id     = module.network.mysql_subnet_id
  private_dns_zone_id     = module.network.private_dns_zone_id
  private_dns_zone_link   = module.network.private_dns_zone_link

  depends_on = [module.network]
}

module "network" {
  source              = "./modules/network"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
}
