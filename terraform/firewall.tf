# Firewall rule for SSH access to jumper host
resource "google_compute_firewall" "jumper_ssh" {
  name    = local.security_config.jumper_firewall_name
  network = google_compute_network.vpc_network.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.allowed_ssh_cidrs
  target_tags   = ["jumper"]
}

# Firewall rule for internal communication in private subnet - ALL traffic between cluster nodes
resource "google_compute_firewall" "private_internal" {
  name    = "${local.security_config.private_firewall_name}-internal"
  network = google_compute_network.vpc_network.name
  project = var.project_id

  # Allow ALL TCP traffic between cluster nodes
  allow {
    protocol = "tcp"
    ports    = ["1-65535"]
  }

  # Allow ALL UDP traffic between cluster nodes
  allow {
    protocol = "udp"
    ports    = ["1-65535"]
  }

  # Allow ICMP for ping and network diagnostics
  allow {
    protocol = "icmp"
  }

  # Only allow traffic from cluster nodes to cluster nodes
  source_tags = ["k8s-cluster"]
  target_tags = ["k8s-cluster"]
}

# Firewall rule for jumper to cluster SSH access (specific port only)
resource "google_compute_firewall" "jumper_to_cluster" {
  name    = "${local.security_config.private_firewall_name}-jumper"
  network = google_compute_network.vpc_network.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["2222"]
  }

  source_tags = ["jumper"]
  target_tags = ["k8s-cluster"]
}

# Firewall rule for load balancer
resource "google_compute_firewall" "lb_health_check" {
  name    = "${local.security_config.lb_firewall_name}-health"
  network = google_compute_network.vpc_network.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "30080", "30443"]
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"] # Google Cloud health check ranges
  target_tags   = ["k8s-cluster"]
}

# Firewall rule for HTTP/HTTPS from internet to load balancer
resource "google_compute_firewall" "lb_external" {
  name    = "${local.security_config.lb_firewall_name}-external"
  network = google_compute_network.vpc_network.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["load-balancer"]
}