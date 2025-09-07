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

# resource "azurerm_resource_group" "main" {
#   name     = "sz-the-devops"
#   location = "Southeast Asia"
# }

module "compute" {
  source                = "./modules/compute"
  resource_group_name   = data.azurerm_resource_group.main.name
  location              = data.azurerm_resource_group.main.location
  network_interface_ids = module.network.nic_ids
}

module "database" {
  source                  = "./modules/database"
  resource_group_name     = data.azurerm_resource_group.main.name
  location                = data.azurerm_resource_group.main.location
  db_admin_login          = var.db_admin_login
  db_admin_login_password = var.db_admin_login_password
  start_ip_address        = module.network.public_ip_address
  end_ip_address          = module.network.public_ip_address
  delegated_subnet_id     = module.network.subnet_id
  private_dns_zone_id     = module.network.private_dns_zone_id
  private_dns_zone_link   = module.network.private_dns_zone_link
}

module "network" {
  source              = "./modules/network"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
}
