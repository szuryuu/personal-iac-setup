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

variable "ssh_public_key" {
  type        = string
  description = "The public SSH key to use for the Semaphore VM"
}

variable "vm_size" {
  type        = string
  description = "The size of the virtual machine"
  default     = "Standard_B2s"
}

variable "semaphore_subnet_id" {
  type        = string
  description = "Subnet ID for Semaphore"
}
