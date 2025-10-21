output "vm_subnet_id" {
  value = azurerm_subnet.vm_subnet.id
}

# MySQL Outputs
output "mysql_subnet_id" {
  value = azurerm_subnet.mysql_subnet.id
}

output "mysql_private_dns_zone_id" {
  description = "The ID of the MySQL Private DNS Zone."
  value = one(concat(
    azurerm_private_dns_zone.mysql_dns_zone.*.id,
    data.azurerm_private_dns_zone.existing_mysql_dns_zone.*.id
  ))
}

output "mysql_private_dns_zone_link" {
  value = azurerm_private_dns_zone_virtual_network_link.mysql_dns_zone_link.id
}

# PostgreSQL Outputs
output "postgresql_subnet_id" {
  value = azurerm_subnet.postgresql_subnet.id
}

output "postgresql_private_dns_zone_id" {
  description = "The ID of the PostgreSQL Private DNS Zone."
  value = one(concat(
    azurerm_private_dns_zone.postgresql_dns_zone.*.id,
    data.azurerm_private_dns_zone.existing_postgresql_dns_zone.*.id
  ))
}

output "postgresql_private_dns_zone_link" {
  value = azurerm_private_dns_zone_virtual_network_link.postgresql_dns_zone_link.id
}

# Boundary Outputs
output "boundary_subnet_id" {
  description = "The ID of the Boundary subnet"
  value       = azurerm_subnet.boundary_controller_subnet.id
}

# Semaphore Outputs
output "semaphore_subnet_id" {
  description = "The ID of the Semaphore subnet"
  value       = azurerm_subnet.semaphore_subnet.id
}

# VM Outputs
output "vm_public_ip" {
  description = "The public IP address of the VM"
  value       = azurerm_public_ip.vm_public_ip.ip_address
}

output "nic_ids" {
  value = [azurerm_network_interface.nic.id]
}

# Legacy output for backward compatibility
output "private_dns_zone_id" {
  description = "The ID of the MySQL Private DNS Zone (legacy)."
  value = one(concat(
    azurerm_private_dns_zone.mysql_dns_zone.*.id,
    data.azurerm_private_dns_zone.existing_mysql_dns_zone.*.id
  ))
}

output "private_dns_zone_link" {
  description = "MySQL DNS zone link (legacy)"
  value       = azurerm_private_dns_zone_virtual_network_link.mysql_dns_zone_link.id
}
