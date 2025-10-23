# Azure Configuration
variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
  sensitive   = true
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group"
}

# Key Vault
variable "key_vault_name" {
  type        = string
  description = "The name of the key vault"
}

variable "project_name" {
  type        = string
  description = "The name of the project"
  default     = "dev-area"
}

# Virtual Machine
variable "vm_size" {
  type        = string
  description = "The size of the virtual machine"
  default     = "Standard_B1s"
}

variable "semaphore_admin_password" {
  type        = string
  description = "Semaphore admin password"
  sensitive   = true
  default     = "changeme"
}

variable "semaphore_subnet_cidr" {
  type        = string
  description = "The CIDR block for the Semaphore subnet"
  default     = "10.0.5.0/24"
}

variable "shared_vnet_cidr" {
  type        = string
  description = "The CIDR block for the shared VNet"
  default     = "10.0.0.0/16"
}

variable "boundary_subnet_cidr" {
  type        = string
  description = "The CIDR block for the Boundary subnet"
  default     = "10.0.4.0/24"
}
