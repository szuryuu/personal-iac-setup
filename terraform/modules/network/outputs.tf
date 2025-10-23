output "vm_subnet_id" {
  value = azurerm_subnet.vm_subnet.id
}

# VM Outputs
output "vm_public_ip" {
  description = "The public IP address of the VM"
  value       = azurerm_public_ip.vm_public_ip.ip_address
}

output "nic_ids" {
  value = [azurerm_network_interface.nic.id]
}

output "vnet_id" {
  description = "The ID of the virtual network."
  value       = azurerm_virtual_network.network.id
}

output "vnet_name" {
  description = "The name of the virtual network."
  value       = azurerm_virtual_network.network.name
}
