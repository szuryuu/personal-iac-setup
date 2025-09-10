output "vm_public_ip" {
  description = "The public IP address of the virtual machine."
  value       = module.network.public_ip_address
}
