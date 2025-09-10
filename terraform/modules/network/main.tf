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

resource "azurerm_subnet" "mysql_subnet" {
  name                 = "${var.environment}-mysql-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = [var.mysql_subnet_cidr]
  service_endpoints    = ["Microsoft.Storage"]

  dynamic "delegation" {
    for_each = var.create_mysql_delegation ? [1] : []
    content {
      name = "mysql-delegation"
      service_delegation {
        name = "Microsoft.DBforMySQL/flexibleServers"
        actions = [
          "Microsoft.Network/virtualNetworks/subnets/join/action",
        ]
      }
    }
  }
}

resource "azurerm_private_dns_zone" "dns_zone" {
  count               = var.create_mysql_delegation ? 1 : 0
  name                = "privatelink.mysql.database.azure.com"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_zone_link" {
  count                 = var.create_mysql_delegation ? 1 : 0
  name                  = "${var.environment}-dns-vnet-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.dns_zone[0].name
  virtual_network_id    = azurerm_virtual_network.network.id
  registration_enabled  = false
}

resource "azurerm_public_ip" "public_ip" {
  name                = "${var.environment}-ip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "nsg" {
  name                = "${var.environment}-nsg"
  resource_group_name = var.resource_group_name
  location            = var.location

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "nic" {
  name                = "${var.environment}-nic"
  resource_group_name = var.resource_group_name
  location            = var.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_subnet_network_security_group_association" "subnet_nsg" {
  subnet_id                 = azurerm_subnet.vm_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
