output "vm_subnet_id" {
  value = azurerm_subnet.vm_subnet.id
}

output "mysql_subnet_id" {
  value = azurerm_subnet.mysql_subnet.id
}

output "boundary_subnet_id" {
  description = "The ID of the Boundary subnet"
  value       = azurerm_subnet.boundary_controller_subnet.id
}

output "private_dns_zone_id" {
  description = "The ID of the Private DNS Zone."
  value = one(concat(
    azurerm_private_dns_zone.dns_zone.*.id,
    data.azurerm_private_dns_zone.existing_dns_zone.*.id
  ))
}

output "private_dns_zone_link" {
  value = azurerm_private_dns_zone_virtual_network_link.dns_zone_link.id
}

output "vm_public_ip" {
  description = "The public IP address of the VM"
  value       = azurerm_public_ip.vm_public_ip.ip_address
}

output "nic_ids" {
  value = [azurerm_network_interface.nic.id]
}
