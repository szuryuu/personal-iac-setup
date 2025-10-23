output "vm_public_ip" {
  description = "The public IP address of the virtual machine."
  value       = module.network.vm_public_ip
}

output "vm_private_ip" {
  description = "The private IP address of the virtual machine."
  value       = module.compute.private_ip_address
}

output "vm_username" {
  description = "The username of the virtual machine."
  value       = "adminuser"
}

output "environment" {
  description = "The environment in which the virtual machine is deployed."
  value       = var.environment
}

output "project_name" {
  description = "The name of the project."
  value       = var.project_name
}

# output "ansible_inventory" {
#   description = "Ansible inventory in JSON format"
#   value = jsonencode({
#     "${var.environment}" = {
#       hosts = {
#         "${var.project_name}-${var.environment}-vm" = {
#           ansible_host                 = module.compute.private_ip_address
#           ansible_user                 = "adminuser"
#           ansible_ssh_private_key_file = "~/.ssh/id_rsa"
#           ansible_ssh_common_args      = var.boundary_target_id != null ? "-o ProxyCommand='boundary connect ssh -target-id ${var.boundary_target_id} -listen-port %p -- %h'" : ""
#           environment                  = var.environment
#           project_name                 = var.project_name
#           mysql_host                   = module.database.mysql_fqdn
#         }
#         "boundary-server" = {
#           ansible_host                 = module.boundary.boundary_private_ip
#           ansible_user                 = "adminuser"
#           ansible_ssh_private_key_file = "~/.ssh/id_rsa"
#           environment                  = var.environment
#           project_name                 = var.project_name
#           postgresql_host              = module.database.postgresql_fqdn
#         }
#       }
#       vars = {
#         environment      = var.environment
#         project_name     = var.project_name
#         boundary_api_url = module.boundary.boundary_api_url
#         mysql_host       = module.database.mysql_fqdn
#         postgresql_host  = module.database.postgresql_fqdn
#       }
#     }
#   })
# }

output "vnet_id" {
  description = "The ID of the dev virtual network."
  value       = module.network.vnet_id
}

output "vnet_name" {
  description = "The name of the dev virtual network."
  value       = module.network.vnet_name
}
