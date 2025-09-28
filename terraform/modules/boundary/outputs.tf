output "boundary_vm_id" {
  description = "The ID of the Boundary VM"
  value       = azurerm_linux_virtual_machine.boundary_combined.id
}

output "boundary_private_ip" {
  description = "The private IP address of the Boundary VM"
  value       = azurerm_linux_virtual_machine.boundary_combined.private_ip_address
}

output "boundary_public_ip" {
  description = "The public IP address of the Boundary VM"
  value       = azurerm_public_ip.boundary_pip.ip_address
}

output "boundary_api_url" {
  description = "Boundary API URL"
  value       = "http://${azurerm_public_ip.boundary_pip.ip_address}:9200"
}

output "boundary_proxy_url" {
  description = "Boundary Worker Proxy URL"
  value       = "${azurerm_public_ip.boundary_pip.ip_address}:9202"
}

output "boundary_nic_id" {
  description = "The ID of the Boundary network interface"
  value       = azurerm_network_interface.boundary_nic.id
}

output "worker_auth_key" {
  description = "Worker authentication key"
  value       = random_password.worker_auth_key.result
  sensitive   = true
}
