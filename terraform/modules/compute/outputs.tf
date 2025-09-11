output "vm_name" {
  description = "The name of the virtual machine"
  value       = azurerm_linux_virtual_machine.main.name
}

output "vm_id" {
  description = "The ID of the virtual machine"
  value       = azurerm_linux_virtual_machine.main.id
}

output "private_ip_address" {
  description = "The private IP address of the virtual machine"
  value       = azurerm_linux_virtual_machine.main.private_ip_address
}
