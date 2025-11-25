output "observability_private_ip" {
  description = "Private IP address of the Observability VM"
  value       = azurerm_linux_virtual_machine.observability.private_ip_address
}

output "observability_public_ip" {
  description = "Public IP address of the Observability VM"
  value       = azurerm_linux_virtual_machine.observability.public_ip_address
}

output "tool_private_ip" {
  description = "Private IP address of the Tool VM"
  value       = azurerm_linux_virtual_machine.tool.private_ip_address
}

output "tool_public_ip" {
  description = "Public IP address of the Tool VM"
  value       = azurerm_public_ip.tool_pip.ip_address
}

output "boundary_public_ip" {
  description = "Public IP address of the Boundary server"
  value       = azurerm_public_ip.boundary_pip.ip_address
}

output "boundary_private_ip" {
  description = "Private IP address of the Boundary server"
  value       = azurerm_linux_virtual_machine.boundary.private_ip_address
}

output "boundary_api_url" {
  description = "Boundary API URL for client connections (http://<boundary_public_ip>:9200)"
  value       = "http://${azurerm_public_ip.boundary_pip.ip_address}:9200"
}

output "boundary_proxy_url" {
  description = "Boundary Proxy URL for client connections (http://<boundary_public_ip>:9202)"
  value       = "http://${azurerm_public_ip.boundary_pip.ip_address}:9202"
}
