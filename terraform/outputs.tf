output "jumper_external_ip" {
  description = "External IP of the jumper host"
  value       = google_compute_instance.jumper.network_interface[0].access_config[0].nat_ip
}

output "jumper_ssh_command" {
  description = "SSH command to connect to jumper host"
  value       = "ssh ubuntu@${google_compute_instance.jumper.network_interface[0].access_config[0].nat_ip}"
}

output "master_internal_ips" {
  description = "Internal IPs of master nodes"
  value       = [for instance in google_compute_instance.master_nodes : instance.network_interface[0].network_ip]
}

output "worker_internal_ips" {
  description = "Internal IPs of worker nodes"
  value       = [for instance in google_compute_instance.worker_nodes : instance.network_interface[0].network_ip]
}

output "load_balancer_ip" {
  description = "External IP of the load balancer"
  value       = google_compute_global_forwarding_rule.k8s_http_forwarding_rule.ip_address
}

output "cluster_access_commands" {
  description = "Commands to access cluster nodes from jumper"
  value = merge(
    {
      for i, instance in google_compute_instance.master_nodes :
      "master-${i + 1}" => "ssh -i ~/.ssh/cluster_key -p 2222 ubuntu@${instance.network_interface[0].network_ip}"
    },
    {
      for i, instance in google_compute_instance.worker_nodes :
      "worker-${i + 1}" => "ssh -i ~/.ssh/cluster_key -p 2222 ubuntu@${instance.network_interface[0].network_ip}"
    }
  )
}

output "ansible_inventory_info" {
  description = "Information for Ansible inventory"
  value = {
    masters = [
      for i, instance in google_compute_instance.master_nodes : {
        name = instance.name
        ip   = instance.network_interface[0].network_ip
        role = "master"
      }
    ]
    workers = [
      for i, instance in google_compute_instance.worker_nodes : {
        name = instance.name
        ip   = instance.network_interface[0].network_ip
        role = "worker"
      }
    ]
  }
}

output "private_key_pem" {
  description = "Private key for cluster access (sensitive)"
  value       = tls_private_key.cluster_ssh.private_key_pem
  sensitive   = true
}

output "public_key" {
  description = "Public key for cluster access"
  value       = tls_private_key.cluster_ssh.public_key_openssh
}