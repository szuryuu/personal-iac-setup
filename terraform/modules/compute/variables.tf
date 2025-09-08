variable "resource_group_name" {
  type        = string
  description = "The name of the resource group"
}

variable "location" {
  type        = string
  description = "The location of the resource group"
}

variable "network_interface_ids" {
  type        = list(string)
  description = "The IDs of the network interfaces"
}

variable "ssh_public_key" {
  type        = string
  description = "The public SSH key to use for the VM"
}
