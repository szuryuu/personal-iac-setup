resource "azurerm_mssql_server" "main" {
  name                         = "main-sqlserver"
  resource_group_name          = data.azurerm_resource_group.main.name
  location                     = data.azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = var.db_admin_login
  administrator_login_password = var.db_admin_login_password
}

resource "azurerm_mssql_firewall_rule" "main" {
  name                = "main-firewall-rule"
  resource_group_name = data.azurerm_resource_group.main.name
  server_name         = azurerm_mssql_server.main.name
  start_ip_address    = var.start_ip_address
  end_ip_address      = var.end_ip_address
}

resource "azurerm_mssql_database" "main" {
  name         = "mysql-db"
  server_id    = azurerm_mssql_server.main.id
  collation    = "SQL_Latin1_General_CP1_CI_AS"
  license_type = "LicenseIncluded"
  max_size_gb  = 2
  sku_name     = "S0"
  enclave_type = "VBS"

  tags = {
    foo = "bar"
  }

  # prevent the possibility of accidental data loss
  lifecycle {
    prevent_destroy = true
  }
}
