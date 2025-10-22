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

# Environment Configuration
variable "environment" {
  type        = string
  description = "The environment name"
  default     = "dev"
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

variable "location" {
  type        = string
  description = "The location of the resource group"
}

variable "ssh_public_key" {
  type        = string
  description = "The public SSH key to use for the Semaphore VM"
}

variable "ssh_private_key" {
  type        = string
  description = "The private SSH key to use for the Semaphore VM"
}

variable "semaphore_admin_password" {
  type        = string
  description = "Semaphore admin password"
  sensitive   = true
  default     = "changeme"
}

variable "boundary_ip" {
  type        = string
  description = "Boundary server IP"
}

variable "vm_ip" {
  type        = string
  description = "Dev VM private IP"
}

variable "semaphore_subnet_id" {
  type        = string
  description = "Subnet ID for Semaphore"
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
