resource "azurerm_linux_virtual_machine" "boundary_worker" {
  count               = var.deploy_boundary_worker ? 1 : 0
  name                = "${var.project_name}-${var.environment}-boundary-worker"
  admin_username      = "adminuser"
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

  custom_data = base64encode(templatefile("${path.module}/boundary-worker-init.sh", {
    boundary_worker_token = var.boundary_worker_token
    boundary_cluster_url  = var.boundary_cluster_url
  }))

  tags = {
    environment = var.environment
    project     = var.project_name
    service     = "boundary-worker"
  }
}

resource "azurerm_network_interface" "boundary_worker_nic" {
  count               = var.deploy_boundary_worker ? 1 : 0
  name                = "${var.environment}-boundary-worker-nic"
  resource_group_name = var.resource_group_name
  location            = var.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.boundary_worker_subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.boundary_worker_pip[0].id
  }
}

resource "azurerm_public_ip" "boundary_worker_pip" {
  count               = var.deploy_boundary_worker ? 1 : 0
  name                = "${var.environment}-boundary-worker-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
}
