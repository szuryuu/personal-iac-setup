# Project Configuration
variable "project_name" {
  type        = string
  description = "The name of the project"
  default     = "dev-area"
}

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

# Networking
variable "shared_vnet_cidr" {
  type        = string
  description = "The CIDR block for the shared VNet"
  default     = "10.0.0.0/16"
}

variable "tool_subnet_cidr" {
  type        = string
  description = "The CIDR block for the tool subnet"
}

variable "observability_subnet_cidr" {
  type        = string
  description = "The CIDR block for the tool subnet"
}

variable "boundary_subnet_cidr" {
  type        = string
  description = "The CIDR block for the Boundary subnet"
}

# Virtual Machine
variable "vm_size" {
  type        = string
  description = "The size of the virtual machine"
  default     = "Standard_B1s"
}

variable "tool_admin_password" {
  type        = string
  description = "Tool admin password"
  sensitive   = true
  default     = "changeme"
}
