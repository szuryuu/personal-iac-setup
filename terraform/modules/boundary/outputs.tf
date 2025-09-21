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
