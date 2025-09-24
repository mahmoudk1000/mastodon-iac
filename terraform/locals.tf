locals {
  common_tags = {
    Environment = var.environment
    Project     = var.cluster_name
    ManagedBy   = "terraform"
    Owner       = "devops"
  }
  
  cluster_nodes = {
    master = {
      machine_type = var.machine_type
      disk_size    = var.disk_size
      role         = "master"
    }
    worker = {
      machine_type = var.machine_type
      disk_size    = var.disk_size
      role         = "worker"
    }
  }
  
  network_config = {
    vpc_name              = "${var.cluster_name}-vpc"
    private_subnet_name   = "${var.cluster_name}-private-subnet"
    public_subnet_name    = "${var.cluster_name}-public-subnet"
    nat_gateway_name      = "${var.cluster_name}-nat-gateway"
    router_name           = "${var.cluster_name}-router"
  }
  
  security_config = {
    jumper_firewall_name = "${var.cluster_name}-jumper-allow"
    private_firewall_name = "${var.cluster_name}-private-allow"
    lb_firewall_name     = "${var.cluster_name}-lb-allow"
  }
}