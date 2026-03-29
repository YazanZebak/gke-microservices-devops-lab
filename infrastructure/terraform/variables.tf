variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the VM"
  type        = string
  default     = "europe-west3"
}

variable "zone" {
  description = "GCP zone for the VM"
  type        = string
  default     = "europe-west3-a"
}

variable "machine_type" {
  description = "GCE machine type for the load generator VM"
  type        = string
  default     = "e2-medium"
}

variable "frontend_addr" {
  description = "External IP of the Online Boutique frontend (no http:// prefix)"
  type        = string
}

variable "locust_users" {
  description = "Number of simulated concurrent users"
  type        = number
  default     = 10
}

variable "locust_spawn_rate" {
  description = "Number of users to spawn per second"
  type        = number
  default     = 1
}
