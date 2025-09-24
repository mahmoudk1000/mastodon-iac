#!/bin/bash
set -e

# Update system
apt-get update -y
apt-get upgrade -y

# Install required packages
apt-get install -y curl wget jq git python3 python3-pip

# Install Ansible
pip3 install ansible

# Install kubectl
curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update -y
apt-get install -y kubectl

# Set up SSH configuration for accessing cluster nodes on port 2222
cat <<EOF >> /etc/ssh/ssh_config
Host k8s-*
    Port 2222
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF

# Create the private key for cluster access
echo "${cluster_private_key}" | base64 -d > /home/ubuntu/.ssh/cluster_key
chmod 600 /home/ubuntu/.ssh/cluster_key
chown ubuntu:ubuntu /home/ubuntu/.ssh/cluster_key

# Create SSH config for ubuntu user
cat <<EOF > /home/ubuntu/.ssh/config
Host k8s-master-*
    HostName %h
    User ubuntu
    Port 2222
    IdentityFile ~/.ssh/cluster_key
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host k8s-worker-*
    HostName %h
    User ubuntu
    Port 2222
    IdentityFile ~/.ssh/cluster_key
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host 10.0.1.*
    User ubuntu
    Port 2222
    IdentityFile ~/.ssh/cluster_key
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF

chmod 600 /home/ubuntu/.ssh/config
chown ubuntu:ubuntu /home/ubuntu/.ssh/config

# Parse JSON arrays and create variables
MASTER_IPS='${master_ips}'
WORKER_IPS='${worker_ips}'
MASTER_NAMES='${master_names}'
WORKER_NAMES='${worker_names}'

# Create Ansible inventory
mkdir -p /home/ubuntu/ansible
cat <<EOF > /home/ubuntu/ansible/hosts.ini
[k8s_masters]
EOF

# Add master nodes to inventory
echo "$MASTER_IPS" | jq -r 'to_entries[] | "\(.key) \(.value)"' | while read index ip; do
  master_name=$(echo "$MASTER_NAMES" | jq -r ".[$index]")
  echo "$master_name ansible_host=$ip ansible_user=ubuntu ansible_port=2222 ansible_ssh_private_key_file=~/.ssh/cluster_key" >> /home/ubuntu/ansible/hosts.ini
done

cat <<EOF >> /home/ubuntu/ansible/hosts.ini

[k8s_workers]
EOF

# Add worker nodes to inventory
echo "$WORKER_IPS" | jq -r 'to_entries[] | "\(.key) \(.value)"' | while read index ip; do
  worker_name=$(echo "$WORKER_NAMES" | jq -r ".[$index]")
  echo "$worker_name ansible_host=$ip ansible_user=ubuntu ansible_port=2222 ansible_ssh_private_key_file=~/.ssh/cluster_key" >> /home/ubuntu/ansible/hosts.ini
done

cat <<EOF >> /home/ubuntu/ansible/hosts.ini

[k8s_cluster:children]
k8s_masters
k8s_workers
EOF

# Create ansible.cfg
cat <<EOF > /home/ubuntu/ansible/ansible.cfg
[defaults]
inventory = hosts.ini
remote_user = ubuntu
private_key_file = ~/.ssh/cluster_key
host_key_checking = False
timeout = 30
retry_files_enabled = False

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes
pipelining = True
EOF

# Clone your k8s_init Ansible role
cd /home/ubuntu/ansible
git clone https://github.com/mahmoudk1000/k8s_init.git
cd k8s_init

# Set ownership
chown -R ubuntu:ubuntu /home/ubuntu/ansible

# Create convenience scripts for Ansible
cat <<EOF > /home/ubuntu/run-k8s-init.sh
#!/bin/bash
cd /home/ubuntu/ansible/k8s_init
ansible-playbook -i ../hosts.ini main.yml
EOF

cat <<EOF > /home/ubuntu/check-cluster-connectivity.sh
#!/bin/bash
cd /home/ubuntu/ansible
echo "Testing connectivity to all nodes..."
ansible k8s_cluster -m ping
EOF

cat <<EOF > /home/ubuntu/setup-kubectl.sh
#!/bin/bash
# This script should be run after Kubernetes is initialized via Ansible
# It copies the kubeconfig from the first master node

MASTER_IP=\$(echo '${master_ips}' | jq -r '.[0]')

echo "Copying kubectl config from master node at \$MASTER_IP..."
mkdir -p /home/ubuntu/.kube

# Wait for cluster to be ready and copy kubectl config
for i in {1..20}; do
  if scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /home/ubuntu/.ssh/cluster_key -P 2222 ubuntu@\$MASTER_IP:/home/ubuntu/.kube/config /home/ubuntu/.kube/config 2>/dev/null; then
    echo "✓ kubectl config copied successfully"
    chown ubuntu:ubuntu /home/ubuntu/.kube/config
    chmod 600 /home/ubuntu/.kube/config
    break
  fi
  echo "Waiting for kubectl config... attempt \$i/20"
  sleep 30
done

# Test kubectl
kubectl get nodes
EOF

chmod +x /home/ubuntu/*.sh
chown ubuntu:ubuntu /home/ubuntu/*.sh

# Add host entries for easier access
echo "$MASTER_IPS" | jq -r 'to_entries[] | "\(.value) k8s-master-\(.key + 1)"' >> /etc/hosts
echo "$WORKER_IPS" | jq -r 'to_entries[] | "\(.value) k8s-worker-\(.key + 1)"' >> /etc/hosts

# Create kubectl alias and completion for ubuntu user
echo 'alias k=kubectl' >> /home/ubuntu/.bashrc
echo 'complete -F __start_kubectl k' >> /home/ubuntu/.bashrc
echo 'source <(kubectl completion bash)' >> /home/ubuntu/.bashrc
echo 'export PATH=$PATH:/home/ubuntu/.local/bin' >> /home/ubuntu/.bashrc

echo "Jumper host setup completed"
echo "Next steps:"
echo "1. Run: ./check-cluster-connectivity.sh"
echo "2. Run: ./run-k8s-init.sh"
echo "3. Run: ./setup-kubectl.sh"