output "semaphore_private_ip" {
  description = "Semaphore VM private IP"
  value       = azurerm_linux_virtual_machine.semaphore.private_ip_address
}

output "semaphore_public_ip" {
  description = "The public IP address of the Semaphore VM"
  value       = azurerm_public_ip.semaphore_pip.ip_address
}

output "boundary_public_ip" {
  description = "Public IP address of Boundary server in shared"
  value       = azurerm_public_ip.boundary_pip.ip_address
}

output "boundary_private_ip" {
  description = "Private IP address of Boundary server in shared"
  value       = azurerm_linux_virtual_machine.boundary.private_ip_address
}

output "boundary_api_url" {
  description = "Boundary API URL for client connections"
  value       = "http://${azurerm_public_ip.boundary_pip.ip_address}:9200"
}

output "boundary_proxy_url" {
  description = "Boundary Proxy URL for client connections"
  value       = "http://${azurerm_public_ip.boundary_pip.ip_address}:9202"
}
