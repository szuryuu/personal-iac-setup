resource "azurerm_linux_virtual_machine" "semaphore" {
  name                = "${var.project_name}-${var.environment}-semaphore"
  admin_username      = "adminuser"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = "Standard_B2s"

  disable_password_authentication = true
  provision_vm_agent              = true
  allow_extension_operations      = false

  network_interface_ids = [azurerm_network_interface.semaphore_nic.id]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/azure_vm_key_dev_test1.pub")
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

  tags = {
    environment = var.environment
    project     = var.project_name
    role        = "semaphore"
  }
}
