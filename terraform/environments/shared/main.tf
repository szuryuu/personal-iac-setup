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
  name         = "ssh-public-keys"
  key_vault_id = data.azurerm_key_vault.existing.id
}

data "azurerm_key_vault_secret" "ssh_private_key" {
  name         = "ssh-private-keys-nopass"
  key_vault_id = data.azurerm_key_vault.existing.id
}

data "azurerm_key_vault_secret" "db_password" {
  name         = "db-password-login-creds"
  key_vault_id = data.azurerm_key_vault.existing.id
}

data "azurerm_key_vault_secret" "db_username" {
  name         = "db-username-login-creds"
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

# data "terraform_remote_state" "staging" {
#   backend = "azurerm"
#   config = {
#     resource_group_name  = "devops-intern-sandbox-rg-sandbox-sea"
#     storage_account_name = "tfstateintern"
#     container_name       = "tfstate"
#     key                  = "staging.terraform.tfstate"
#   }
# }

# data "terraform_remote_state" "prod" {
#   backend = "azurerm"
#   config = {
#     resource_group_name  = "devops-intern-sandbox-rg-sandbox-sea"
#     storage_account_name = "tfstateintern"
#     container_name       = "tfstate"
#     key                  = "prod.terraform.tfstate"
#   }
# }

# Tool VM
resource "azurerm_linux_virtual_machine" "tool" {
  name                = "shared-tool-vm"
  admin_username      = "adminuser"
  resource_group_name = var.resource_group_name
  location            = data.azurerm_resource_group.main.location
  size                = var.vm_size

  disable_password_authentication = true
  provision_vm_agent              = true
  allow_extension_operations      = false

  network_interface_ids = [azurerm_network_interface.tool_nic.id]

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

  custom_data = base64encode(templatefile("${path.module}/scripts/tools-init.sh", {
    admin_password   = var.tool_admin_password
    db_dialect       = "bolt"
    ansible_repo_url = "https://github.com/szuryuu/personal-iac-setup"
    ssh_private_key  = data.azurerm_key_vault_secret.ssh_private_key.value

    dev_boundary_ip = azurerm_public_ip.boundary_pip.ip_address
    dev_vm_ip       = try(data.terraform_remote_state.dev.outputs.vm_private_ip, "")

    staging_boundary_ip = ""
    staging_vm_ip       = ""

    prod_boundary_ip = ""
    prod_vm_ip       = ""

  }))

  tags = {
    environment = "shared"
    project     = var.project_name
    role        = "tool"
  }
}

# Boundary VM
resource "azurerm_linux_virtual_machine" "boundary" {
  name                = "shared-boundary-vm"
  resource_group_name = var.resource_group_name
  location            = data.azurerm_resource_group.main.location
  size                = var.vm_size
  admin_username      = "adminuser"

  disable_password_authentication = true

  admin_ssh_key {
    username   = "adminuser"
    public_key = data.azurerm_key_vault_secret.ssh_public_key.value
  }

  network_interface_ids = [azurerm_network_interface.boundary_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/scripts/boundary-init.sh", {
    db_username = data.azurerm_key_vault_secret.db_username.value
    db_password = data.azurerm_key_vault_secret.db_password.value

    encoded_db_password = urlencode(data.azurerm_key_vault_secret.db_password.value)
    worker_auth_key     = random_password.worker_auth_key.result
    BOUNDARY_VERSION    = "0.19.3"

    dev_ip     = try(data.terraform_remote_state.dev.outputs.vm_private_ip, "")
    staging_ip = ""
    prod_ip    = ""
  }))

  tags = {
    environment = "shared"
    project     = var.project_name
    service     = "boundary"
  }
}

resource "random_password" "worker_auth_key" {
  length  = 32
  special = false
}
