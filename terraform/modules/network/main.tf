resource "azurerm_virtual_network" "network" {
  name                = "${var.environment}-vnet"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = [var.vnet_cidr]
}

resource "azurerm_subnet" "vm_subnet" {
  name                 = "${var.environment}-vm-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = [var.vm_subnet_cidr]
}

# MYSQL SUBNET
resource "azurerm_subnet" "mysql_subnet" {
  name                 = "${var.environment}-mysql-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = [var.mysql_subnet_cidr]
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "mysql-delegation"
    service_delegation {
      name = "Microsoft.DBforMySQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# POSTGRESQL SUBNET
resource "azurerm_subnet" "postgresql_subnet" {
  name                 = "${var.environment}-postgresql-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = [var.postgresql_subnet_cidr]
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "postgresql-delegation"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# BOUNDARY CONTROLLER SUBNET
resource "azurerm_subnet" "boundary_controller_subnet" {
  name                 = "${var.environment}-boundary-controller-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = [var.boundary_subnet_cidr]
}

# # SEMAPHORE SUBNET
# resource "azurerm_subnet" "semaphore_subnet" {
#   name                 = "${var.environment}-semaphore-subnet"
#   resource_group_name  = var.resource_group_name
#   virtual_network_name = azurerm_virtual_network.network.name
#   address_prefixes     = [var.semaphore_subnet_cidr]
# }

# MYSQL DNS ZONE
resource "azurerm_private_dns_zone" "mysql_dns_zone" {
  count               = var.create_private_dns_zone || var.is_terratest ? 1 : 0
  name                = "privatelink.mysql.database.azure.com"
  resource_group_name = var.resource_group_name
}

data "azurerm_private_dns_zone" "existing_mysql_dns_zone" {
  count               = !var.create_private_dns_zone && !var.is_terratest ? 1 : 0
  name                = "privatelink.mysql.database.azure.com"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "mysql_dns_zone_link" {
  name                  = "${var.environment}-mysql-dns-vnet-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = (var.create_private_dns_zone || var.is_terratest) ? azurerm_private_dns_zone.mysql_dns_zone[0].name : data.azurerm_private_dns_zone.existing_mysql_dns_zone[0].name
  virtual_network_id    = azurerm_virtual_network.network.id
  registration_enabled  = false
}

# POSTGRESQL DNS ZONE
resource "azurerm_private_dns_zone" "postgresql_dns_zone" {
  count               = var.create_private_dns_zone || var.is_terratest ? 1 : 0
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
}

data "azurerm_private_dns_zone" "existing_postgresql_dns_zone" {
  count               = !var.create_private_dns_zone && !var.is_terratest ? 1 : 0
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgresql_dns_zone_link" {
  name                  = "${var.environment}-postgresql-dns-vnet-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = (var.create_private_dns_zone || var.is_terratest) ? azurerm_private_dns_zone.postgresql_dns_zone[0].name : data.azurerm_private_dns_zone.existing_postgresql_dns_zone[0].name
  virtual_network_id    = azurerm_virtual_network.network.id
  registration_enabled  = false
}

# NETWORK SECURITY GROUPS
resource "azurerm_network_security_group" "vm_nsg" {
  name                = "${var.environment}-vm-nsg"
  resource_group_name = var.resource_group_name
  location            = var.location

  security_rule {
    name                       = "Allow-SSH-From-Boundary"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.environment
  }
}

resource "azurerm_network_security_group" "database_nsg" {
  name                = "${var.environment}-database-nsg"
  resource_group_name = var.resource_group_name
  location            = var.location

  security_rule {
    name                       = "MySQL"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "PostgreSQL"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.environment
  }
}

resource "azurerm_network_security_group" "boundary_worker_nsg" {
  name                = "${var.environment}-boundary-worker-nsg"
  resource_group_name = var.resource_group_name
  location            = var.location

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

# PUBLIC IP & NIC
resource "azurerm_public_ip" "vm_public_ip" {
  name                = "${var.environment}-vm-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic" {
  name                = "${var.environment}-nic"
  resource_group_name = var.resource_group_name
  location            = var.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_public_ip.id
  }
}

# NSG ASSOCIATIONS
resource "azurerm_subnet_network_security_group_association" "vm_subnet_nsg" {
  subnet_id                 = azurerm_subnet.vm_subnet.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "mysql_subnet_nsg" {
  subnet_id                 = azurerm_subnet.mysql_subnet.id
  network_security_group_id = azurerm_network_security_group.database_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "postgresql_subnet_nsg" {
  subnet_id                 = azurerm_subnet.postgresql_subnet.id
  network_security_group_id = azurerm_network_security_group.database_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "boundary_subnet_nsg" {
  subnet_id                 = azurerm_subnet.boundary_controller_subnet.id
  network_security_group_id = azurerm_network_security_group.boundary_worker_nsg.id
}
