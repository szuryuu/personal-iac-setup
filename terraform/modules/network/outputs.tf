output "public_ip_address" {
  value = azurerm_public_ip.public_ip.ip_address
}

output "nic_ids" {
  value = [azurerm_network_interface.nic.id]
}
