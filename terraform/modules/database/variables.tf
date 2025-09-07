variable "db_admin_login" {
  type        = string
  description = "The administrator login for the Azure SQL Server"
}

variable "db_admin_login_password" {
  type        = string
  description = "The administrator login password for the Azure SQL Server"
}

variable "start_ip_address" {
  type = string
}

variable "end_ip_address" {
  type = string
}
