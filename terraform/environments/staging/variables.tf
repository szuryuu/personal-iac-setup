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

# Database
variable "db_sku_name" {
  type        = string
  description = "The SKU name for the database servers"
  default     = "B_Standard_B1ms"
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

# Networking
variable "vnet_cidr" {
  type        = string
  description = "The CIDR block for the virtual network"
  default     = "10.1.0.0/16"
}

variable "vm_subnet_cidr" {
  type        = string
  description = "The CIDR block for the virtual machine subnet"
  default     = "10.1.1.0/24"
}
