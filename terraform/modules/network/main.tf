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

  delegation {
    name = "fs"
    service_delegation {
      name = "Microsoft.DBforMySQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = [var.bastion_subnet_cidr]
}

resource "azurerm_private_dns_zone" "dns_zone" {
  count               = var.create_private_dns_zone ? 1 : 0
  name                = "privatelink.mysql.database.azure.com"
  resource_group_name = var.resource_group_name
}

data "azurerm_private_dns_zone" "existing_dns_zone" {
  count               = !var.create_private_dns_zone ? 1 : 0
  name                = "privatelink.mysql.database.azure.com"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_zone_link" {
  name                  = "${var.environment}-dns-vnet-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = var.create_private_dns_zone ? azurerm_private_dns_zone.dns_zone[0].name : data.azurerm_private_dns_zone.existing_dns_zone[0].name
  virtual_network_id    = azurerm_virtual_network.network.id
  registration_enabled  = false
}

# resource "azurerm_public_ip" "public_ip" {
#   name                = "${var.environment}-ip"
#   resource_group_name = var.resource_group_name
#   location            = var.location
#   allocation_method   = "Static"
#   sku                 = "Standard"
# }



resource "azurerm_public_ip" "bastion_ip" {
  name                = "${var.environment}-bastion-ip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  name                = "${var.environment}-bastion"
  resource_group_name = var.resource_group_name
  location            = var.location

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion_ip.id
  }
}

# resource "azurerm_network_security_group" "nsg" {
#   name                = "${var.environment}-nsg"
#   resource_group_name = var.resource_group_name
#   location            = var.location

#   security_rule {
#     name                       = "SSH"
#     priority                   = 100
#     direction                  = "Inbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "22"
#     source_address_prefix      = "*"
#     destination_address_prefix = "*"
#   }
# }

resource "azurerm_network_security_group" "mysql_nsg" {
  name                = "${var.environment}-mysql-nsg"
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
}

resource "azurerm_network_interface" "nic" {
  name                = "${var.environment}-nic"
  resource_group_name = var.resource_group_name
  location            = var.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    # public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

# resource "azurerm_subnet_network_security_group_association" "subnet_nsg" {
#   subnet_id                 = azurerm_subnet.vm_subnet.id
#   network_security_group_id = azurerm_network_security_group.nsg.id
# }

resource "azurerm_subnet_network_security_group_association" "mysql_subnet_nsg" {
  subnet_id                 = azurerm_subnet.mysql_subnet.id
  network_security_group_id = azurerm_network_security_group.mysql_nsg.id
}
