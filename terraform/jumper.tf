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

  metadata_startup_script = templatefile("${path.module}/scripts/jumper-init.sh", {
    cluster_private_key = base64encode(tls_private_key.cluster_ssh.private_key_pem)
    master_ips         = jsonencode([for i in google_compute_instance.master_nodes : i.network_interface[0].network_ip])
    worker_ips         = jsonencode([for i in google_compute_instance.worker_nodes : i.network_interface[0].network_ip])
    master_names       = jsonencode([for i in google_compute_instance.master_nodes : i.name])
    worker_names       = jsonencode([for i in google_compute_instance.worker_nodes : i.name])
  })

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