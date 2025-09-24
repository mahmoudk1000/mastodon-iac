# SSH Key for cluster access
resource "tls_private_key" "cluster_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Master node instance
resource "google_compute_instance" "master_nodes" {
  count        = var.master_node_count
  name         = "${var.cluster_name}-master-${count.index + 1}"
  machine_type = local.cluster_nodes.master.machine_type
  zone         = var.zone
  project      = var.project_id

  tags = ["k8s-cluster", "master", "k8s-master"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = local.cluster_nodes.master.disk_size
      type  = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.id
    # No external IP - completely private
  }

  metadata = {
    ssh-keys = "ubuntu:${tls_private_key.cluster_ssh.public_key_openssh}"
  }

  # Minimal startup script - Kubernetes will be installed via Ansible
  metadata_startup_script = <<-EOF
    #!/bin/bash
    # Configure SSH to listen on port 2222
    sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
    sed -i 's/^Port 22/Port 2222/' /etc/ssh/sshd_config
    systemctl restart ssh
    
    # Update system
    apt-get update -y
    apt-get upgrade -y
    
    # Install Python for Ansible
    apt-get install -y python3 python3-pip
    
    # Create marker file to indicate node is ready for Ansible
    touch /tmp/node-ready
    echo "master-${count.index + 1}" > /tmp/node-role
  EOF

  service_account {
    email  = google_service_account.k8s_cluster.email
    scopes = ["cloud-platform"]
  }

  labels = local.common_tags

  depends_on = [google_compute_router_nat.nat]
}

# Worker node instances
resource "google_compute_instance" "worker_nodes" {
  count        = var.worker_node_count
  name         = "${var.cluster_name}-worker-${count.index + 1}"
  machine_type = local.cluster_nodes.worker.machine_type
  zone         = var.zone
  project      = var.project_id

  tags = ["k8s-cluster", "worker", "k8s-worker"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = local.cluster_nodes.worker.disk_size
      type  = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.id
    # No external IP - completely private
  }

  metadata = {
    ssh-keys = "ubuntu:${tls_private_key.cluster_ssh.public_key_openssh}"
  }

  # Minimal startup script - Kubernetes will be installed via Ansible
  metadata_startup_script = <<-EOF
    #!/bin/bash
    # Configure SSH to listen on port 2222
    sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
    sed -i 's/^Port 22/Port 2222/' /etc/ssh/sshd_config
    systemctl restart ssh
    
    # Update system
    apt-get update -y
    apt-get upgrade -y
    
    # Install Python for Ansible
    apt-get install -y python3 python3-pip
    
    # Create marker file to indicate node is ready for Ansible
    touch /tmp/node-ready
    echo "worker-${count.index + 1}" > /tmp/node-role
  EOF

  service_account {
    email  = google_service_account.k8s_cluster.email
    scopes = ["cloud-platform"]
  }

  labels = local.common_tags

  depends_on = [
    google_compute_router_nat.nat
  ]
}

# Service Account for Kubernetes cluster
resource "google_service_account" "k8s_cluster" {
  account_id   = "${var.cluster_name}-sa"
  display_name = "Kubernetes Cluster Service Account"
  project      = var.project_id
}

# IAM roles for the service account
resource "google_project_iam_member" "k8s_compute" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin"
  member  = "serviceAccount:${google_service_account.k8s_cluster.email}"
}

resource "google_project_iam_member" "k8s_storage" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.k8s_cluster.email}"
}