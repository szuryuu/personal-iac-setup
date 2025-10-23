resource "azurerm_virtual_network" "shared" {
  name                = "shared-vnet"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  address_space       = [var.shared_vnet_cidr]
}

# Semaphore
resource "azurerm_subnet" "semaphore_subnet" {
  name                 = "shared-semaphore-subnet"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.shared.name
  address_prefixes     = [var.semaphore_subnet_cidr]
}

resource "azurerm_network_interface" "semaphore_nic" {
  name                = "semaphore-nic"
  resource_group_name = var.resource_group_name
  location            = data.azurerm_resource_group.main.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.semaphore_subnet.id
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
    name                       = "ByteBase"
    priority                   = 106
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
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
  subnet_id                 = azurerm_subnet.semaphore_subnet.id
  network_security_group_id = azurerm_network_security_group.semaphore_nsg.id
}

# Boundary
resource "azurerm_subnet" "boundary_controller_subnet" {
  name                 = "boundary-controller-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.shared.name
  address_prefixes     = [var.boundary_subnet_cidr]
}

resource "azurerm_network_security_group" "boundary_worker_nsg" {
  name                = "boundary-worker-nsg"
  resource_group_name = var.resource_group_name
  location            = data.azurerm_resource_group.main.location

  security_rule {
    name                       = "Boundary-Proxy"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9202"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Boundary-API"
    priority                   = 105
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9200"
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

  lifecycle {
    ignore_changes = [security_rule]
  }
}

resource "azurerm_network_interface" "boundary_nic" {
  name                = "boundary-nic"
  resource_group_name = var.resource_group_name
  location            = data.azurerm_resource_group.main.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.boundary_controller_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.boundary_pip.id
  }
}

resource "azurerm_public_ip" "boundary_pip" {
  name                = "boundary-pip"
  resource_group_name = var.resource_group_name
  location            = data.azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    environment = "shared"
    project     = var.project_name
  }
}

resource "azurerm_subnet_network_security_group_association" "boundary_subnet_nsg" {
  subnet_id                 = azurerm_subnet.boundary_controller_subnet.id
  network_security_group_id = azurerm_network_security_group.boundary_worker_nsg.id
}
