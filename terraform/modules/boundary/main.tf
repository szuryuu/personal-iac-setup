resource "azurerm_linux_virtual_machine" "boundary_combined" {
  name                = "${var.project_name}-${var.environment}-boundary"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  admin_username      = "adminuser"

  disable_password_authentication = true
  admin_ssh_key {
    username   = "adminuser"
    public_key = var.ssh_public_key
  }

  network_interface_ids = var.network_interface_ids

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

  custom_data = base64encode(templatefile("${path.module}/init.sh", {
    db_connection_string = var.db_connection_string
    environment          = var.environment
    project_name         = var.project_name
    worker_auth_key      = random_password.worker_auth_key.result
  }))

  tags = {
    environment = var.environment
    project     = var.project_name
    service     = "boundary-combined"
  }
}

resource "azurerm_network_interface" "boundary_nic" {
  name                = "${var.environment}-boundary-nic"
  resource_group_name = var.resource_group_name
  location            = var.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.boundary_subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.boundary_pip.id
  }
}

resource "azurerm_public_ip" "boundary_pip" {
  name                = "${var.environment}-boundary-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    environment = var.environment
    project     = var.project_name
  }
}

resource "random_password" "worker_auth_key" {
  length  = 32
  special = false
}
