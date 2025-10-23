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

variable "postgresql_subnet_cidr" {
  type        = string
  description = "The CIDR block for the PostgreSQL subnet"
  default     = "10.0.3.0/24"
}

variable "boundary_subnet_cidr" {
  type        = string
  description = "The CIDR block for the Boundary subnet"
  default     = "10.0.4.0/24"
}

# PostgreSQL Network Configuration
variable "postgresql_delegated_subnet_id" {
  type        = string
  description = "The ID of the delegated subnet for PostgreSQL"
}

variable "postgresql_private_dns_zone_id" {
  type        = string
  description = "The ID of the private DNS zone for PostgreSQL"
}

variable "postgresql_private_dns_zone_link" {
  type        = string
  description = "The private DNS zone link for PostgreSQL"
}

variable "create_private_dns_zone" {
  type        = bool
  description = "If true, creates the Private DNS Zone. If false, uses an existing one."
  default     = false
}

variable "is_terratest" {
  type        = bool
  description = "A flag to indicate if the environment is being deployed for a Terratest run."
  default     = false
}
