output "vm_subnet_id" {
  value = azurerm_subnet.vm_subnet.id
}

output "mysql_subnet_id" {
  value = azurerm_subnet.mysql_subnet.id
}

output "private_dns_zone_id" {
  value = azurerm_private_dns_zone.dns_zone.id
}

output "private_dns_zone_link" {
  value = azurerm_private_dns_zone_virtual_network_link.dns_zone_link.id
}

output "public_ip_address" {
  value = azurerm_public_ip.public_ip.ip_address
}

output "nic_ids" {
  value = [azurerm_network_interface.nic.id]
}
