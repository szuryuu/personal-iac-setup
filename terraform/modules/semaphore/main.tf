resource "azurerm_linux_virtual_machine" "semaphore" {
  name                = "${var.project_name}-${var.environment}-semaphore"
  admin_username      = "adminuser"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size

  disable_password_authentication = true
  provision_vm_agent              = true
  allow_extension_operations      = false

  network_interface_ids = [azurerm_network_interface.semaphore_nic.id]

  admin_ssh_key {
    username   = "adminuser"
    public_key = var.ssh_public_key
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

  custom_data = base64encode(templatefile("${path.module}/scripts/install-semaphore.sh", {
    admin_password   = var.semaphore_admin_password
    db_dialect       = var.db_dialect
    ansible_repo_url = var.ansible_repo_url
    ssh_private_key  = var.ssh_private_key
  }))

  tags = {
    environment = var.environment
    project     = var.project_name
    role        = "semaphore"
  }
}

resource "azurerm_network_interface" "semaphore_nic" {
  name                = "${var.environment}-semaphore-nic"
  resource_group_name = var.resource_group_name
  location            = var.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.semaphore_subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.semaphore_pip.id
  }
}

resource "azurerm_public_ip" "semaphore_pip" {
  name                = "${var.environment}-semaphore-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
}
