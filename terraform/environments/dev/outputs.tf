# output "vm_public_ip" {
#   description = "The public IP address of the virtual machine."
#   value       = module.network.public_ip_address
# }

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

output "db_fqdn" {
  description = "The fully qualified domain name of the database."
  value       = module.database.mysql_fqdn
}

output "ansible_inventory" {
  description = "Ansible inventory in JSON format"
  value = jsonencode({
    "${var.environment}" = {
      hosts = {
        "${var.project_name}-${var.environment}-vm" = {
          ansible_host                 = module.compute.private_ip_address
          ansible_user                 = "adminuser"
          ansible_ssh_private_key_file = "~/.ssh/id_rsa"
          ansible_ssh_common_args      = "-o ProxyCommand='az network bastion tunnel --name ${module.network.bastion_host_name} --resource-group ${var.resource_group_name} --target-resource-id ${module.compute.vm_id} --resource-port %p --port %p'"
          environment                  = var.environment
          project_name                 = var.project_name
          mysql_host                   = module.database.mysql_fqdn
        }
      }
      vars = {
        environment  = var.environment
        project_name = var.project_name
      }
    }
  })
}
