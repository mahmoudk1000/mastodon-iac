# VPC Network
resource "google_compute_network" "vpc_network" {
  name                    = local.network_config.vpc_name
  auto_create_subnetworks = false
  project                 = var.project_id
}

# Private Subnet for Kubernetes cluster
resource "google_compute_subnetwork" "private_subnet" {
  name          = local.network_config.private_subnet_name
  ip_cidr_range = var.private_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc_network.id
  project       = var.project_id
  
  private_ip_google_access = true
}

# Public Subnet for jumper host and load balancer
resource "google_compute_subnetwork" "public_subnet" {
  name          = local.network_config.public_subnet_name
  ip_cidr_range = var.public_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc_network.id
  project       = var.project_id
}

# Cloud Router for NAT Gateway
resource "google_compute_router" "router" {
  name    = local.network_config.router_name
  region  = var.region
  network = google_compute_network.vpc_network.id
  project = var.project_id
}

# NAT Gateway for private subnet internet access
resource "google_compute_router_nat" "nat" {
  name                               = local.network_config.nat_gateway_name
  router                            = google_compute_router.router.name
  region                            = var.region
  nat_ip_allocate_option            = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  project                           = var.project_id

  subnetwork {
    name                    = google_compute_subnetwork.private_subnet.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}
