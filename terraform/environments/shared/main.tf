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

# Shared Network
resource "azurerm_virtual_network" "shared" {
  name                = "shared-vnet"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  address_space       = [var.shared_vnet_cidr]
}

resource "azurerm_subnet" "semaphore" {
  name                 = "shared-semaphore-subnet"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.shared.name
  address_prefixes     = [var.semaphore_subnet_cidr]
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

resource "azurerm_network_interface" "semaphore_nic" {
  name                = "semaphore-nic"
  resource_group_name = var.resource_group_name
  location            = data.azurerm_resource_group.main.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.semaphore.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.semaphore_pip.id
  }
}

resource "azurerm_public_ip" "semaphore_pip" {
  name                = "semaphore-pip"
  resource_group_name = var.resource_group_name
  location            = data.azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "semaphore_nsg" {
  name                = "semaphore-nsg"
  resource_group_name = var.resource_group_name
  location            = data.azurerm_resource_group.main.location

  security_rule {
    name                       = "HTTP-Management"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS-Management"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Semaphore-UI"
    priority                   = 105
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SSH-Management"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-To-Environments"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  # lifecycle {
  #   ignore_changes = [security_rule]
  # }
}

resource "azurerm_subnet_network_security_group_association" "semaphore_nsg" {
  subnet_id                 = azurerm_subnet.semaphore.id
  network_security_group_id = azurerm_network_security_group.semaphore_nsg.id
}
