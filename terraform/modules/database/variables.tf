# Resource Group
variable "resource_group_name" {
  type        = string
  description = "The name of the resource group"
}

variable "location" {
  type        = string
  description = "The location of the resource group"
}

# Database
variable "db_admin_login" {
  type        = string
  description = "The administrator login for the Azure SQL Server"
}

variable "db_admin_login_password" {
  type        = string
  description = "The administrator login password for the Azure SQL Server"
}

variable "db_sku_name" {
  type        = string
  description = "The SKU name for the Azure SQL Server"
  default     = "Standard_B1ms"
}

variable "backup_retention_days" {
  type        = number
  description = "The number of days to retain backups"
  default     = 7
}

# Network
variable "delegated_subnet_id" {
  type        = string
  description = "The ID of the delegated subnet"
}

variable "private_dns_zone_id" {
  type        = string
  description = "The ID of the private DNS zone"
}

variable "private_dns_zone_link" {
  type        = string
  description = "The private DNS zone link"
}

# Environment
variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  type        = string
  description = "The name of the project"
  default     = "my_project"
}
