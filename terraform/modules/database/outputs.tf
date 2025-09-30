# MySQL Outputs (untuk aplikasi)
output "mysql_fqdn" {
  description = "The fully qualified domain name of the MySQL server."
  value       = azurerm_mysql_flexible_server.mysql_server.fqdn
}

output "mysql_server_name" {
  description = "The name of the MySQL server."
  value       = azurerm_mysql_flexible_server.mysql_server.name
}

output "mysql_database_name" {
  description = "The name of the MySQL database."
  value       = azurerm_mysql_flexible_database.mysql.name
}

# PostgreSQL Outputs (untuk Boundary)
output "postgresql_fqdn" {
  description = "The fully qualified domain name of the PostgreSQL server."
  value       = azurerm_postgresql_flexible_server.postgresql_server.fqdn
}

output "postgresql_server_name" {
  description = "The name of the PostgreSQL server."
  value       = azurerm_postgresql_flexible_server.postgresql_server.name
}

output "boundary_database_name" {
  description = "The name of the Boundary database."
  value       = azurerm_postgresql_flexible_server_database.boundary_db.name
}
