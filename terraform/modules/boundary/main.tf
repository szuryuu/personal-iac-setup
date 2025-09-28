resource "azurerm_linux_virtual_machine" "boundary" {
  count               = var.deploy_boundary ? 1 : 0
  name                = "boundary-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size

  disable_password_authentication = true
  network_interface_ids           = var.network_interface_ids

  admin_ssh_key {
    username   = "adminuser"
    public_key = var.ssh_public_key
  }

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
  }))

  tags = {
    environment = var.environment
    project     = var.project_name
  }
}

resource "azurerm_network_interface" "boundary_nic" {
  count               = var.deploy_boundary ? 1 : 0
  name                = "${var.environment}-boundary-nic"
  resource_group_name = var.resource_group_name
  location            = var.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.boundary_subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.boundary_pip[0].id
  }
}
