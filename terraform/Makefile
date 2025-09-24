.PHONY: help init plan apply destroy validate clean ssh-jumper get-ips

# Default target
help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Initialize Terraform
	terraform init

plan: ## Plan Terraform deployment
	terraform plan

apply: ## Apply Terraform configuration
	terraform apply

destroy: ## Destroy all resources
	terraform destroy

validate: ## Validate Terraform configuration
	terraform validate
	terraform fmt -check

format: ## Format Terraform files
	terraform fmt -recursive

clean: ## Clean Terraform state and cache
	rm -rf .terraform/
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate*
	rm -f *.tfplan

ssh-jumper: ## SSH to jumper host
	@JUMPER_IP=$$(terraform output -raw jumper_external_ip 2>/dev/null); \
	if [ -n "$$JUMPER_IP" ]; then \
		echo "Connecting to jumper host at $$JUMPER_IP"; \
		ssh ubuntu@$$JUMPER_IP; \
	else \
		echo "Error: Could not get jumper IP. Make sure infrastructure is deployed."; \
		exit 1; \
	fi

get-ips: ## Get all IP addresses
	@echo "=== Infrastructure IP Addresses ==="
	@echo "Jumper External IP: $$(terraform output -raw jumper_external_ip 2>/dev/null || echo 'N/A')"
	@echo "Load Balancer IP: $$(terraform output -raw load_balancer_ip 2>/dev/null || echo 'N/A')"
	@echo ""
	@echo "Master Node IPs:"
	@terraform output -json master_internal_ips 2>/dev/null | jq -r '.[]' | nl -v0 | sed 's/^/  master-/' || echo "  N/A"
	@echo ""
	@echo "Worker Node IPs:"
	@terraform output -json worker_internal_ips 2>/dev/null | jq -r '.[]' | nl -v0 | sed 's/^/  worker-/' || echo "  N/A"

show-outputs: ## Show all Terraform outputs
	terraform output

deploy: init plan apply ## Full deployment (init + plan + apply)
	@echo ""
	@echo "=== Deployment Complete ==="
	@echo ""
	@make get-ips
	@echo ""
	@echo "Next steps:"
	@echo "1. Connect to jumper host: make ssh-jumper"
	@echo "2. Test node connectivity: ./check-cluster-connectivity.sh"
	@echo "3. Initialize Kubernetes: ./run-k8s-init.sh"
	@echo "4. Setup kubectl: ./setup-kubectl.sh"
	@echo "5. Verify cluster: kubectl get nodes"

init-k8s: ## Initialize Kubernetes cluster via Ansible (run from jumper)
	@echo "This command should be run from the jumper host:"
	@echo "1. SSH to jumper: make ssh-jumper"
	@echo "2. Run: ./check-cluster-connectivity.sh"
	@echo "3. Run: ./run-k8s-init.sh"
	@echo "4. Run: ./setup-kubectl.sh"

quick-deploy: ## Quick deployment without confirmation
	terraform apply -auto-approve

gcp-apis: ## Enable required GCP APIs
	@echo "Enabling required GCP APIs..."
	gcloud services enable compute.googleapis.com
	gcloud services enable container.googleapis.com  
	gcloud services enable dns.googleapis.com
	@echo "APIs enabled successfully!"

setup: gcp-apis ## Initial setup (enable APIs and initialize)
	@echo "Running initial setup..."
	@make init
	@echo "Setup completed! Now edit terraform.tfvars and run 'make deploy'"

# CI/CD Pipeline Commands
pipeline-validate: ## Validate configuration for CI/CD
	@echo "=== Pipeline Validation ==="
	@echo "Checking Terraform format..."
	terraform fmt -check -recursive
	@echo "Validating Terraform configuration..."
	terraform validate
	@echo "✅ Pipeline validation completed"

pipeline-setup: ## Setup pipeline prerequisites
	@echo "=== Pipeline Setup Guide ==="
	@echo ""
	@echo "1. Set up GCP Service Account:"
	@echo "   gcloud iam service-accounts create terraform-ci-cd"
	@echo ""
	@echo "2. Add required GitHub secrets:"
	@echo "   - GOOGLE_CREDENTIALS"
	@echo "   - GCP_PROJECT_ID"
	@echo "   - ALLOWED_SSH_CIDRS"
	@echo ""
	@echo "3. Configure GitHub variables:"
	@echo "   - GCP_REGION, GCP_ZONE, CLUSTER_NAME"
	@echo "   - MASTER_NODE_COUNT, WORKER_NODE_COUNT"
	@echo ""
	@echo "4. Review pipeline configuration:"
	@echo "   - .github/workflows/iac.yaml"
	@echo ""
	@echo "📖 Full setup guide: PIPELINE_SETUP.md"

test-scripts: ## Test shell scripts locally
	@echo "=== Testing Shell Scripts ==="
	@for script in scripts/*.sh; do \
		echo "Testing $$script..."; \
		bash -n "$$script" && echo "✅ $$script syntax OK" || echo "❌ $$script has syntax errors"; \
	done