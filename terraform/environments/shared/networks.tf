# Shared Virtual Network
resource "azurerm_virtual_network" "shared" {
  name                = "shared-vnet"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  address_space       = [var.shared_vnet_cidr]
}

# Observability Resources

# Subnet for observability
resource "azurerm_subnet" "observability_subnet" {
  name                 = "shared-observability-subnet"
  resource_group_name  = data.azurerm_resource_group.main
  virtual_network_name = azurerm_virtual_network.shared.name
  address_prefixes     = [var.observability_subnet_cidr]
}

# Public IP for observability
resource "azurerm_public_ip" "observability_pip" {
  name                = "observability-pip"
  resource_group_name = var.resource_group_name
  location            = data.azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network Interface for Observability
resource "azurerm_network_interface" "observability_nic" {
  name                = "observability-nic"
  resource_group_name = var.resource_group_name
  location            = data.azurerm_resource_group.main.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.observability_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.observability_pip.id
  }
}

# Network Security Group for Observability
resource "azurerm_network_security_group" "observability_nsg" {
  name                = "observability-nsg"
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

  # security_rule {
  #   name                       = "HTTPS-Management"
  #   priority                   = 101
  #   direction                  = "Inbound"
  #   access                     = "Allow"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "443"
  #   source_address_prefix      = "Internet"
  #   destination_address_prefix = "*"
  # }

  security_rule {
    name                       = "Grafana"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Promatheus"
    priority                   = 103
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9090"
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

# Associate NSG with Observability Subnet
resource "azurerm_subnet_network_security_group_association" "observability_nsg" {
  subnet_id                 = azurerm_subnet.observability_subnet.id
  network_security_group_id = azurerm_network_security_group.observability_nsg.id
}

# Tool Resources

# Subnet for Tool
resource "azurerm_subnet" "tool_subnet" {
  name                 = "shared-tool-subnet"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.shared.name
  address_prefixes     = [var.tool_subnet_cidr]
}

# Public IP for Tool
resource "azurerm_public_ip" "tool_pip" {
  name                = "tool-pip"
  resource_group_name = var.resource_group_name
  location            = data.azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network Interface for Tool
resource "azurerm_network_interface" "tool_nic" {
  name                = "tool-nic"
  resource_group_name = var.resource_group_name
  location            = data.azurerm_resource_group.main.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.tool_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.tool_pip.id
  }
}

# Network Security Group for Tool
resource "azurerm_network_security_group" "tool_nsg" {
  name                = "tool-nsg"
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

# Associate NSG with Tool Subnet
resource "azurerm_subnet_network_security_group_association" "tool_nsg" {
  subnet_id                 = azurerm_subnet.tool_subnet.id
  network_security_group_id = azurerm_network_security_group.tool_nsg.id
}

# Boundary Resources

# Subnet for Boundary Controller
resource "azurerm_subnet" "boundary_controller_subnet" {
  name                 = "boundary-controller-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.shared.name
  address_prefixes     = [var.boundary_subnet_cidr]
}

# Network Security Group for Boundary Worker
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

# Public IP for Boundary
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

# Network Interface for Boundary
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

# Associate NSG with Boundary Subnet
resource "azurerm_subnet_network_security_group_association" "boundary_subnet_nsg" {
  subnet_id                 = azurerm_subnet.boundary_controller_subnet.id
  network_security_group_id = azurerm_network_security_group.boundary_worker_nsg.id
}
