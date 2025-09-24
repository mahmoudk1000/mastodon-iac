# Health check for the load balancer
resource "google_compute_health_check" "k8s_health_check" {
  name    = "${var.cluster_name}-health-check"
  project = var.project_id

  timeout_sec        = 5
  check_interval_sec = 5

  http_health_check {
    port         = 30080
    request_path = "/healthz"
  }
}

# Backend service
resource "google_compute_backend_service" "k8s_backend" {
  name        = "${var.cluster_name}-backend"
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30
  project     = var.project_id

  health_checks = [google_compute_health_check.k8s_health_check.id]

  dynamic "backend" {
    for_each = google_compute_instance.worker_nodes
    content {
      group = google_compute_instance_group.worker_group.id
    }
  }
}

# Instance group for worker nodes
resource "google_compute_instance_group" "worker_group" {
  name        = "${var.cluster_name}-worker-group"
  description = "Kubernetes worker nodes instance group"
  zone        = var.zone
  project     = var.project_id

  instances = [for instance in google_compute_instance.worker_nodes : instance.id]

  named_port {
    name = "http"
    port = "30080"
  }

  named_port {
    name = "https"
    port = "30443"
  }
}

# URL map
resource "google_compute_url_map" "k8s_url_map" {
  name            = "${var.cluster_name}-url-map"
  default_service = google_compute_backend_service.k8s_backend.id
  project         = var.project_id
}

# HTTP proxy
resource "google_compute_target_http_proxy" "k8s_http_proxy" {
  name    = "${var.cluster_name}-http-proxy"
  url_map = google_compute_url_map.k8s_url_map.id
  project = var.project_id
}

# HTTPS proxy (requires SSL certificate)
resource "google_compute_managed_ssl_certificate" "k8s_ssl_cert" {
  name    = "${var.cluster_name}-ssl-cert"
  project = var.project_id

  managed {
    domains = ["example.com"] # Replace with your domain
  }
}

resource "google_compute_target_https_proxy" "k8s_https_proxy" {
  name             = "${var.cluster_name}-https-proxy"
  url_map          = google_compute_url_map.k8s_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.k8s_ssl_cert.id]
  project          = var.project_id
}

# Global forwarding rule for HTTP
resource "google_compute_global_forwarding_rule" "k8s_http_forwarding_rule" {
  name       = "${var.cluster_name}-http-rule"
  target     = google_compute_target_http_proxy.k8s_http_proxy.id
  port_range = "80"
  project    = var.project_id
}

# Global forwarding rule for HTTPS
resource "google_compute_global_forwarding_rule" "k8s_https_forwarding_rule" {
  name       = "${var.cluster_name}-https-rule"
  target     = google_compute_target_https_proxy.k8s_https_proxy.id
  port_range = "443"
  project    = var.project_id
}