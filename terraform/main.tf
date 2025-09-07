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
  name = "devops-intern-sandbox-rg-sandbox-sea"
}

# resource "azurerm_resource_group" "main" {
#   name     = "sz-the-devops"
#   location = "Southeast Asia"
# }

module "compute" {
  source = "./modules/compute"
}

module "database" {
  source                       = "./modules/database"
  administrator_login          = var.db_admin_login
  administrator_login_password = var.db_admin_login_password
  start_ip_address             = module.network.public_ip
  end_ip_address               = module.network.public_ip
}

module "network" {
  source = "./modules/network"
}
