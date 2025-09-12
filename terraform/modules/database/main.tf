resource "azurerm_mysql_flexible_database" "mysql" {
  name                = "${var.environment}-mysql-db"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.mysql_server.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}

resource "azurerm_mysql_flexible_server" "mysql_server" {
  name                   = "${var.project_name}-${var.environment}-mysql-server"
  resource_group_name    = var.resource_group_name
  location               = var.location
  administrator_login    = var.db_admin_login
  administrator_password = var.db_admin_login_password
  backup_retention_days  = var.backup_retention_days
  delegated_subnet_id    = var.delegated_subnet_id
  private_dns_zone_id    = var.private_dns_zone_id
  sku_name               = var.db_sku_name
  # zone                   = "1"

  public_network_access_enabled = false

  tags = {
    environment = var.environment
    project     = var.project_name
  }
}

resource "azurerm_private_endpoint" "mysql_private_endpoint" {
  name                = "${var.project_name}-${var.environment}-mysql-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.project_name}-${var.environment}-mysql-psc"
    private_connection_resource_id = azurerm_mysql_flexible_server.mysql_server.id
    subresource_names              = ["mysqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "mysql-dns-zone-group"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }

  tags = {
    environment = var.environment
    project     = var.project_name
  }
}

# Commenting because db firewall rule is not required and db is not exposed to public network
# resource "azurerm_mysql_flexible_server_firewall_rule" "sql_firewall_rule" {
#   name                = "${var.environment}-sql-firewall-rule"
#   resource_group_name = var.resource_group_name
#   server_name         = azurerm_mysql_flexible_server.mysql_server.name
#   start_ip_address    = var.start_ip_address
#   end_ip_address      = var.end_ip_address
# }

# SQL Configuration
resource "azurerm_mysql_flexible_server_configuration" "sql_mode" {
  name                = "sql_mode"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.mysql_server.name
  value               = "STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO"
}

resource "azurerm_mysql_flexible_server_configuration" "time_zone" {
  name                = "time_zone"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.mysql_server.name
  value               = "+07:00"
}

# Enable SSL enforcement
resource "azurerm_mysql_flexible_server_configuration" "require_secure_transport" {
  name                = "require_secure_transport"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.mysql_server.name
  value               = "ON"
}
