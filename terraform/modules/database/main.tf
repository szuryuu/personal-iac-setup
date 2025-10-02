resource "null_resource" "wait_for_mysql_subnet" {
  provisioner "local-exec" {
    command = "sleep 30"
  }

  triggers = {
    mysql_subnet_id = var.mysql_delegated_subnet_id
  }
}

resource "null_resource" "wait_for_postgresql_subnet" {
  provisioner "local-exec" {
    command = "sleep 30"
  }

  triggers = {
    postgresql_subnet_id = var.postgresql_delegated_subnet_id
  }
}

# MYSQL (for application)
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
  delegated_subnet_id    = var.mysql_delegated_subnet_id
  private_dns_zone_id    = var.mysql_private_dns_zone_id
  sku_name               = var.db_sku_name

  geo_redundant_backup_enabled = var.environment == "prod" ? true : false

  tags = {
    environment = var.environment
    project     = var.project_name
    purpose     = "application"
  }

  depends_on = [var.mysql_private_dns_zone_link]
}

# MySQL Configuration
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

resource "azurerm_mysql_flexible_server_configuration" "require_secure_transport" {
  name                = "require_secure_transport"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.mysql_server.name
  value               = "ON"
}

# POSTGRESQL (for Boundary)
resource "azurerm_postgresql_flexible_server" "postgresql_server" {
  name                   = "${var.project_name}-${var.environment}-postgresql-server"
  resource_group_name    = var.resource_group_name
  location               = var.location
  administrator_login    = var.db_admin_login
  administrator_password = var.db_admin_login_password
  backup_retention_days  = var.backup_retention_days
  delegated_subnet_id    = var.postgresql_delegated_subnet_id
  private_dns_zone_id    = var.postgresql_private_dns_zone_id
  sku_name               = var.db_sku_name
  storage_mb             = 32768
  version                = "16"

  # Disable public network access when using VNet integration
  public_network_access_enabled = false

  geo_redundant_backup_enabled = var.environment == "prod" ? true : false

  tags = {
    environment = var.environment
    project     = var.project_name
    purpose     = "boundary"
  }

  depends_on = [var.postgresql_private_dns_zone_link]
}

resource "azurerm_postgresql_flexible_server_database" "boundary_db" {
  name      = "boundary"
  server_id = azurerm_postgresql_flexible_server.postgresql_server.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# PostgreSQL Configuration
resource "azurerm_postgresql_flexible_server_configuration" "timezone" {
  name      = "timezone"
  server_id = azurerm_postgresql_flexible_server.postgresql_server.id
  value     = "Asia/Jakarta"
}

resource "azurerm_postgresql_flexible_server_configuration" "ssl_mode" {
  name      = "require_secure_transport"
  server_id = azurerm_postgresql_flexible_server.postgresql_server.id
  value     = "on"
}

# Enable some extensions for Boundary
resource "azurerm_postgresql_flexible_server_configuration" "azure_extensions" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.postgresql_server.id
  value     = "BTREE_GIST,CITEXT,HSTORE,PG_TRGM,PGCRYPTO,UUID-OSSP"
}
