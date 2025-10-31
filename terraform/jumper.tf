# Jumper host for accessing the cluster
resource "google_compute_instance" "jumper" {
  name         = "${var.cluster_name}-jumper"
  machine_type = "e2-small"
  zone         = var.zone
  project      = var.project_id

  tags = ["jumper"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.public_subnet.id
    access_config {
      # Ephemeral external IP
    }
  }

  metadata = {
    ssh-keys = "ubuntu:${tls_private_key.cluster_ssh.public_key_openssh}"
  }

  service_account {
    email  = google_service_account.jumper.email
    scopes = ["cloud-platform"]
  }

  labels = local.common_tags
}

# Service Account for jumper host
resource "google_service_account" "jumper" {
  account_id   = "${var.cluster_name}-jumper-sa"
  display_name = "Jumper Host Service Account"
  project      = var.project_id
}

# IAM role for jumper to access compute instances
resource "google_project_iam_member" "jumper_compute" {
  project = var.project_id
  role    = "roles/compute.viewer"
  member  = "serviceAccount:${google_service_account.jumper.email}"
}