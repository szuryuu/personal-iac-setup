resource "azurerm_linux_virtual_machine" "boundary_controller" {
  count               = var.deploy_boundary_worker ? 1 : 0
  name                = "boundary-controller-${var.environment}"
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

  custom_data = base64encode(templatefile("${path.module}/controller-init.sh", {
    db_connection_string = var.db_connection_string
    environment          = var.environment
  }))

  tags = {
    environment = var.environment
    service     = "boundary-controller"
  }
}
