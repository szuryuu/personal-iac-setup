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
  name         = "dev-vm-ssh-public-keys"
  key_vault_id = data.azurerm_key_vault.existing.id
}

data "azurerm_key_vault_secret" "ssh_private_key" {
  name         = "dev-vm-ssh-private-keys-nopass"
  key_vault_id = data.azurerm_key_vault.existing.id
}

data "terraform_remote_state" "dev" {
  backend = "azurerm"
  config = {
    resource_group_name  = "devops-intern-sandbox-rg-sandbox-sea"
    storage_account_name = "tfstateintern"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"
  }
}

data "terraform_remote_state" "staging" {
  backend = "azurerm"
  config = {
    resource_group_name  = "devops-intern-sandbox-rg-sandbox-sea"
    storage_account_name = "tfstateintern"
    container_name       = "tfstate"
    key                  = "staging.terraform.tfstate"
  }
}

data "terraform_remote_state" "prod" {
  backend = "azurerm"
  config = {
    resource_group_name  = "devops-intern-sandbox-rg-sandbox-sea"
    storage_account_name = "tfstateintern"
    container_name       = "tfstate"
    key                  = "prod.terraform.tfstate"
  }
}

resource "azurerm_linux_virtual_machine" "semaphore" {
  name                = "shared-semaphore"
  admin_username      = "adminuser"
  resource_group_name = var.resource_group_name
  location            = data.azurerm_resource_group.main.location
  size                = var.vm_size

  disable_password_authentication = true
  provision_vm_agent              = true
  allow_extension_operations      = false

  network_interface_ids = [azurerm_network_interface.semaphore_nic.id]

  admin_ssh_key {
    username   = "adminuser"
    public_key = data.azurerm_key_vault_secret.ssh_public_key.value
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 64
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/scripts/semaphore-init.sh", {
    admin_password   = var.semaphore_admin_password
    db_dialect       = "bolt"
    ansible_repo_url = "https://github.com/szuryuu/personal-iac-setup"
    ssh_private_key  = data.azurerm_key_vault_secret.ssh_private_key.value

    dev_boundary_ip = try(data.terraform_remote_state.dev.outputs.boundary_public_ip, "")
    dev_vm_ip       = try(data.terraform_remote_state.dev.outputs.vm_private_ip, "")
  }))

  tags = {
    project = var.project_name
    role    = "semaphore"
  }
}
