output "semaphore_private_ip" {
  description = "Semaphore VM private IP"
  value       = azurerm_linux_virtual_machine.semaphore.private_ip_address
}

output "semaphore_public_ip" {
  description = "The public IP address of the Semaphore VM"
  value       = azurerm_public_ip.semaphore_pip.ip_address
}
