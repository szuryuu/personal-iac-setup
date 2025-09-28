# Azure Infrastructure
variable "resource_group_name" {
  type        = string
  description = "The name of the resource group"
}

variable "location" {
  type        = string
  description = "The location of the resource group"
}

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

# Virtual Machine Configuration
variable "vm_size" {
  type        = string
  description = "The size of the virtual machine"
  default     = "Standard_B1s"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for Boundary worker"
}

# Boundary Worker Configuration
variable "deploy_boundary" {
  type        = bool
  description = "Deploy self-managed Boundary worker"
  default     = true
}

variable "boundary_subnet_id" {
  type        = string
  description = "Subnet ID for Boundary worker"
}

# Database Configuration
variable "db_connection_string" {
  type        = string
  description = "Database connection string"
}

variable "network_interface_ids" {
  type        = list(string)
  description = "The IDs of the network interfaces"
}

variable "worker_auth_key" {
  type        = string
  description = "Worker authentication key"
}
