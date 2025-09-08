variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
  sensitive   = true
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group"
}

variable "key_vault_name" {
  type        = string
  description = "The name of the key vault"
}

# Database administrator login credentials
variable "db_admin_login" {
  type        = string
  description = "The administrator login for the Azure SQL Server"
}

variable "db_admin_login_password" {
  type        = string
  description = "The administrator login password for the Azure SQL Server"
}
