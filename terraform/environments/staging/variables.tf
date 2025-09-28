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
  description = "The SKU name for the Azure SQL Server"
  default     = "B_Standard_B1ms"
}

variable "backup_retention_days" {
  type        = number
  description = "The number of days to retain backups"
  default     = 7
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

# Boundary VM
variable "boundary_vm_size" {
  type        = string
  description = "The size of the Boundary virtual machine"
  default     = "Standard_B2s"
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

variable "mysql_subnet_cidr" {
  type        = string
  description = "The CIDR block for the MySQL subnet"
  default     = "10.1.2.0/24"
}

# Boundary subnet
variable "boundary_subnet_cidr" {
  type        = string
  description = "The CIDR block for the Boundary subnet"
  default     = "10.1.3.0/24"
}

variable "private_endpoint_subnet_id" {
  type        = string
  description = "The ID of the subnet for the private endpoint"
  default     = null
}

variable "is_terratest" {
  type    = bool
  default = false
}

variable "boundary_cluster_url" {
  type        = string
  description = "Boundary cluster URL"
  default     = "https://10.1.3.0:9200"
}

variable "boundary_target_id" {
  type        = string
  description = "The ID of the Boundary target"
  default     = null
}
