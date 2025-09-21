# Azure Resource Group
variable "resource_group_name" {
  type        = string
  description = "The name of the resource group"
}

variable "location" {
  type        = string
  description = "The location of the resource group"
}

# Networking
variable "vnet_cidr" {
  type        = string
  description = "The CIDR block for the virtual network"
  default     = "10.0.0.0/16"
}

variable "vm_subnet_cidr" {
  type        = string
  description = "The CIDR block for the virtual machine subnet"
  default     = "10.0.1.0/24"
}

variable "mysql_subnet_cidr" {
  type        = string
  description = "The CIDR block for the MySQL subnet"
  default     = "10.0.2.0/24"
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

variable "boundary_subnet_cidr" {
  type        = string
  description = "The CIDR block for the Boundary subnet"
  default     = "10.0.3.0/24"
}

variable "boundary_worker_subnet_cidr" {
  type        = string
  description = "The CIDR block for the Boundary worker subnet"
  default     = "10.0.4.0/24"
}
