variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "k8s-cluster"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "master_node_count" {
  description = "Number of master nodes"
  type        = number
  default     = 1
  validation {
    condition     = var.master_node_count >= 1 && var.master_node_count <= 5
    error_message = "Master node count must be between 1 and 5."
  }
}

variable "worker_node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
  validation {
    condition     = var.worker_node_count >= 1 && var.worker_node_count <= 10
    error_message = "Worker node count must be between 1 and 10."
  }
}

variable "machine_type" {
  description = "Machine type for VMs"
  type        = string
  default     = "e2-medium"
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 50
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH to jumper"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}