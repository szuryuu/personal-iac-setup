# Azure Resource Group
variable "resource_group_name" {
  type        = string
  description = "The name of the resource group"
}

variable "location" {
  type        = string
  description = "The location of the resource group"
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

# boundary_worker
variable "deploy_boundary_worker" {
  type        = bool
  description = "Deploy self-managed Boundary worker"
  default     = false
}

variable "boundary_worker_token" {
  type        = string
  description = "Boundary worker authorization token"
  sensitive   = true
}

variable "boundary_cluster_url" {
  type        = string
  description = "Boundary cluster URL"
}

variable "boundary_worker_subnet_id" {
  type        = string
  description = "Subnet ID for Boundary worker"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for Boundary worker"
}

# Virtual Machine
variable "vm_size" {
  type        = string
  description = "The size of the virtual machine"
  default     = "Standard_B1s"
}

variable "db_connection_string" {
  type        = string
  description = "Database connection string"
}
