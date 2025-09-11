output "mysql_fqdn" {
  description = "The fully qualified domain name of the MySQL server."
  value       = azurerm_mysql_flexible_server.mysql_server.fqdn
}

output "mysql_server_name" {
  description = "The name of the MySQL server."
  value       = azurerm_mysql_flexible_server.mysql_server.name
}

output "mysql_server_database_name" {
  description = "The name of the MySQL database."
  value       = azurerm_mysql_flexible_server.mysql_server.database_name
}
