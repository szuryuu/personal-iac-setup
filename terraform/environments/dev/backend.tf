terraform {
  backend "azurerm" {
    resource_group_name  = "devops-intern-sandbox-rg-sandbox-sea"
    storage_account_name = "tfstateintern"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"
  }
}
