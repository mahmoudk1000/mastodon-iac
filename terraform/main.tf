# Main Terraform configuration for secure air-gapped Kubernetes cluster
# This file serves as the entry point and orchestrates all modules

terraform {
  required_version = ">= 1.13.3"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# Data source to get project information
data "google_project" "current" {
  project_id = var.project_id
}