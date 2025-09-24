#!/bin/bash
# Ansible-based Kubernetes cluster validation script
# Run this script from the jumper host after Ansible initialization

set -e

echo "=== Ansible-based Kubernetes Cluster Validation ==="
echo

# Check if kubectl config exists
if [ ! -f "/home/ubuntu/.kube/config" ]; then
    echo "❌ kubectl config not found. Please run ./setup-kubectl.sh first"
    exit 1
fi

# Check cluster info
echo "1. Cluster Information:"
kubectl cluster-info
echo

# Check nodes
echo "2. Node Status:"
kubectl get nodes -o wide
echo

# Check if all nodes are ready
echo "3. Node Readiness Check:"
NOT_READY=$(kubectl get nodes --no-headers | grep -v " Ready " | wc -l)
if [ "$NOT_READY" -eq 0 ]; then
    echo "✅ All nodes are ready"
else
    echo "❌ $NOT_READY node(s) are not ready"
    kubectl get nodes --no-headers | grep -v " Ready "
fi
echo

# Check system pods
echo "4. System Pods Status:"
kubectl get pods -n kube-system
echo

# Check if all system pods are running
echo "5. System Pods Health Check:"
NOT_RUNNING=$(kubectl get pods -n kube-system --no-headers | grep -v "Running\|Completed" | wc -l)
if [ "$NOT_RUNNING" -eq 0 ]; then
    echo "✅ All system pods are running"
else
    echo "❌ $NOT_RUNNING system pod(s) are not running"
    kubectl get pods -n kube-system --no-headers | grep -v "Running\|Completed"
fi
echo

# Test DNS resolution
echo "6. DNS Resolution Test:"
if kubectl run test-dns --image=busybox --restart=Never --rm -i --quiet -- nslookup kubernetes.default > /dev/null 2>&1; then
    echo "✅ DNS resolution is working"
else
    echo "❌ DNS resolution is not working"
fi
echo

# Deploy test application if not already deployed
echo "7. Test Application Deployment:"
if kubectl get deployment nginx-test > /dev/null 2>&1; then
    echo "✅ Test application already deployed"
else
    echo "Deploying test application..."
    kubectl apply -f /home/ubuntu/k8s-manifests/nginx-test.yaml > /dev/null 2>&1
    echo "✅ Test application deployed"
fi
echo

# Wait for pods to be ready
echo "8. Waiting for test pods to be ready..."
kubectl wait --for=condition=ready pod -l app=nginx-test --timeout=120s
echo "✅ Test pods are ready"
echo

# Check service
echo "9. Service Status:"
kubectl get svc nginx-test-service
echo

# Test internal connectivity
echo "10. Testing Internal Connectivity:"
POD_NAME=$(kubectl get pods -l app=nginx-test -o jsonpath='{.items[0].metadata.name}')
if kubectl exec $POD_NAME -- wget -q -O- kubernetes.default.svc.cluster.local > /dev/null 2>&1; then
    echo "✅ Pod can reach Kubernetes API"
else
    echo "❌ Pod cannot reach Kubernetes API"
fi
echo

# Test NodePort service
echo "11. Testing NodePort Service:"
WORKER_NODES=$(kubectl get nodes -l node-role.kubernetes.io/worker -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')
if [ -n "$WORKER_NODES" ]; then
    WORKER_IP=$(echo $WORKER_NODES | cut -d' ' -f1)
    echo "Testing NodePort service on $WORKER_IP:30080"
    if curl -s --max-time 10 "http://$WORKER_IP:30080/healthz" | grep -q "healthy"; then
        echo "✅ NodePort service is responding correctly"
    else
        echo "❌ NodePort service is not responding correctly"
    fi
else
    echo "⚠️  No worker nodes found, testing on any available node"
    ANY_NODE=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    if curl -s --max-time 10 "http://$ANY_NODE:30080/healthz" | grep -q "healthy"; then
        echo "✅ NodePort service is responding correctly"
    else
        echo "❌ NodePort service is not responding correctly"
    fi
fi
echo

# Final summary
echo "=== Validation Summary ==="
echo "Cluster endpoint: $(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
echo "Current context: $(kubectl config current-context)"
echo "Total nodes: $(kubectl get nodes --no-headers | wc -l)"
echo "Ready nodes: $(kubectl get nodes --no-headers | grep " Ready " | wc -l)"
echo "Master nodes: $(kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers | wc -l)"
echo "Worker nodes: $(kubectl get nodes -l node-role.kubernetes.io/worker --no-headers | wc -l || echo "0")"
echo "System pods: $(kubectl get pods -n kube-system --no-headers | wc -l)"
echo "Running system pods: $(kubectl get pods -n kube-system --no-headers | grep "Running" | wc -l)"
echo "Test pods: $(kubectl get pods -l app=nginx-test --no-headers | wc -l)"
echo

# Check cluster component health
echo "12. Cluster Component Health:"
kubectl get componentstatuses 2>/dev/null || echo "⚠️  Component status API may not be available (normal in newer K8s versions)"
echo

echo "✅ Cluster validation completed successfully!"
echo
echo "Next steps:"
echo "1. Access the load balancer external IP: $(terraform output -raw load_balancer_ip 2>/dev/null || echo 'Check terraform output')"
echo "2. Deploy your applications using kubectl"
echo "3. Monitor cluster health and logs"
echo "4. Scale your cluster by modifying terraform variables if needed"