#!/bin/bash

# Set hostname
hostnamectl set-hostname k8s-controller
add-apt-repository universe
apt update
apt install -y ansible python3 python3-pip python3-venv git
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Prepare workspace for Ansible playbooks
mkdir -p /home/ubuntu/ansible
chown ubuntu:ubuntu /home/ubuntu/ansible
chmod 755 /home/ubuntu/ansible

# Ansible.cfg
cat <<'EOF' >/home/ubuntu/ansible/ansible.cfg
[defaults]
inventory = inventory.ini
remote_user = ubuntu
private_key_file = ~/KP.pem
host_key_checking = False
retry_files_enabled = False
deprecation_warnings = False

[ssh_connection]
pipelining = True
EOF

# Inventory files
cat <<EOF >/home/ubuntu/ansible/inventory.ini
[control_plane]
control-plane ansible_host="10.0.1.10"

[workers]
worker-1 ansible_host="10.0.1.11"
worker-2 ansible_host="10.0.2.11"

[all:vars]
ansible_python_interpreter=/usr/bin/python3
EOF

# K8S Deployment Playbook
cat <<'EOF' >/home/ubuntu/ansible/k8s.yml
- name: Install Kubernetes prerequisites
  hosts: all
  become: yes
  vars:
    kubernetes_version: "1.29.2-00"
    pod_network_cidr: "10.244.0.0/16"
  tasks:
    - name: Ensure apt cache is updated
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Install required packages (base)
      apt:
        name:
          - apt-transport-https
          - ca-certificates
          - curl
          - gnupg
          - containerd
        state: present

    - name: Create keyrings directory
      file:
        path: /etc/apt/keyrings
        state: directory
        mode: '0755'

    - name: Remove existing Kubernetes repository if present
      file:
        path: /etc/apt/sources.list.d/kubernetes.list
        state: absent

    - name: Remove existing GPG key if present
      file:
        path: /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        state: absent

    - name: Download and import Kubernetes GPG key
      shell: |
        curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    - name: Add Kubernetes repository
      copy:
        content: "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /\n"
        dest: /etc/apt/sources.list.d/kubernetes.list
        mode: '0644'


    - name: Update apt cache after adding Kubernetes repo
      apt:
        update_cache: yes
        cache_valid_time: 0

    - name: Install Kubernetes packages (latest from repo)
      apt:
        name:
          - kubelet
          - kubeadm
          - kubectl
        state: present
        update_cache: yes

    - name: Hold kube packages at current version
      shell: apt-mark hold kubelet kubeadm kubectl

    - name: Enable and start containerd
      systemd:
        name: containerd
        enabled: yes
        state: started

    - name: Load br_netfilter module
      modprobe:
        name: br_netfilter
        state: present

    - name: Ensure br_netfilter loads at boot
      lineinfile:
        path: /etc/modules-load.d/k8s.conf
        line: br_netfilter
        create: yes

    - name: Configure kernel parameters for Kubernetes
      shell: |
        if ! grep -q "net.bridge.bridge-nf-call-iptables" /etc/sysctl.d/k8s.conf 2>/dev/null; then
          echo 'net.bridge.bridge-nf-call-iptables = 1' >> /etc/sysctl.d/k8s.conf
        fi
        if ! grep -q "net.ipv4.ip_forward" /etc/sysctl.d/k8s.conf 2>/dev/null; then
          echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.d/k8s.conf
        fi
        sysctl --system

- name: Initialize control-plane node
  hosts: control_plane
  become: yes
  vars:
    kubernetes_version: "1.29.2-00"
    pod_network_cidr: "10.244.0.0/16"
  tasks:

    - name: Initialize Kubernetes control plane
      command: kubeadm init --pod-network-cidr={{ pod_network_cidr }} --ignore-preflight-errors=Mem
      args:
        creates: /etc/kubernetes/admin.conf

    - name: Configure kubeconfig for ubuntu user
      command: "{{ item }}"
      with_items:
        - mkdir -p /home/ubuntu/.kube
        - cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
        - chown ubuntu:ubuntu /home/ubuntu/.kube/config

    - name: Wait for Kubernetes API server to be ready
      shell: |
        timeout=180
        elapsed=0
        while [ $elapsed -lt $timeout ]; do
          if kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes 2>/dev/null; then
            echo "API server is ready"
            exit 0
          fi
          echo "Waiting for API server... ($elapsed/$timeout seconds)"
          sleep 5
          elapsed=$((elapsed + 5))
        done
        echo "API server did not become ready in time"
        exit 1
      register: api_wait
      failed_when: api_wait.rc != 0

    - name: Generate join command file
      shell: |
        sleep 15
        for i in {1..5}; do
          if cmd=$(kubeadm token create --print-join-command 2>/dev/null); then
            echo "$cmd"
            exit 0
          fi
          echo "Attempt $i failed, retrying in 10 seconds..."
          sleep 10
        done
        echo "Failed to create join token after 5 attempts"
        exit 1
      register: join_cmd
      changed_when: false

    - name: Save join command locally
      copy:
        content: "{{ join_cmd.stdout }} --cri-socket unix:///var/run/containerd/containerd.sock"
        dest: /home/ubuntu/join-command.sh
        mode: "0700"
        
    - name: Install Flannel CNI plugin
      shell: |
        kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
      args:
        creates: /tmp/flannel-installed
      register: flannel_install
      changed_when: flannel_install.rc == 0

    - name: Wait for Flannel to be ready
      shell: |
        timeout=180
        elapsed=0
        node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
        while [ $elapsed -lt $timeout ]; do
          flannel_running=$(kubectl get pods -n kube-flannel --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
          flannel_ready=$(kubectl get pods -n kube-flannel --field-selector=status.phase=Running --no-headers 2>/dev/null | grep -c "1/1\|2/2" || echo "0")
          if [ "$flannel_running" -ge "$node_count" ] && [ "$flannel_ready" -ge "$node_count" ]; then
            echo "Flannel is ready ($flannel_ready/$node_count pods ready)"
            exit 0
          fi
          echo "Waiting for Flannel... Running: $flannel_running/$node_count, Ready: $flannel_ready/$node_count ($elapsed/$timeout seconds)"
          sleep 5
          elapsed=$((elapsed + 5))
        done
        echo "Flannel did not become fully ready in time, but continuing..."
        exit 0
      register: flannel_wait
      failed_when: false
      when: flannel_install.rc == 0

    - name: Remove taint from control plane to allow pod scheduling
      shell: |
        kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
        kubectl taint nodes --all node-role.kubernetes.io/master- || true
      ignore_errors: yes
EOF

# NFS Deployment Playbook
cat <<EOF >/home/ubuntu/ansible/nfs.yml
- name: Configure NFS server on control plane
  hosts: control_plane
  become: yes
  vars:
    nfs_export_dir: /srv/nfs/k8s
    nfs_mount_dir: /mnt/nfs/k8s
    nfs_clients_cidr: "10.0.0.0/16"
    nfs_server_ip: "10.0.1.10"
  tasks:
    - name: Install NFS server packages
      apt:
        name: nfs-kernel-server
        state: present

    - name: Create export directory
      file:
        path: "{{ nfs_export_dir }}"
        state: directory
        mode: "0777"

    - name: Configure /etc/exports
      lineinfile:
        path: /etc/exports
        line: "{{ nfs_export_dir }} {{ nfs_clients_cidr }}(rw,sync,no_subtree_check,no_root_squash)"
        create: yes

    - name: Reload NFS exports
      command: exportfs -ra

    - name: Ensure NFS server is running
      systemd:
        name: nfs-kernel-server
        enabled: yes
        state: restarted

- name: Configure NFS clients on workers
  hosts: workers
  become: yes
  vars:
    nfs_export_dir: /srv/nfs/k8s
    nfs_mount_dir: /mnt/nfs/k8s
    nfs_clients_cidr: "10.0.0.0/16"
    nfs_server_ip: "10.0.1.10"
  tasks:
    - name: Install NFS common packages
      apt:
        name: nfs-common
        state: present

    - name: Create mount directory
      file:
        path: "{{ nfs_mount_dir }}"
        state: directory
        mode: "0755"

    - name: Ensure NFS mount present
      mount:
        path: "{{ nfs_mount_dir }}"
        src: "{{ nfs_server_ip }}:{{ nfs_export_dir }}"
        fstype: nfs
        opts: rw
        state: mounted
EOF

# Setting permissions
chown -R ubuntu:ubuntu /home/ubuntu/ansible
chmod 640 /home/ubuntu/ansible/*.yml /home/ubuntu/ansible/inventory.ini /home/ubuntu/ansible/ansible.cfg 2>/dev/null || true

# Prepare workspace for Helm charts
mkdir -p /home/ubuntu/helm/templates
chown ubuntu:ubuntu /home/ubuntu/helm
chmod 755 /home/ubuntu/helm
chmod 755 /home/ubuntu/helm/templates

# Chart.yaml
cat <<'EOF' >/home/ubuntu/helm/Chart.yaml
# Helm chart for ITAM Flask application
apiVersion: v2
name: itam-app
description: ITAM Flask web application
type: application
version: 1.0.0
appVersion: "1.0"

EOF

# values.yaml
cat <<'EOF' >/home/ubuntu/helm/values.yaml
# Default values for itam-app
replicaCount: 2

image:
  repository: docker.io/<your-dockerhub-username>/itam-app
  tag: "latest"
  pullPolicy: Always

service:
  type: NodePort
  port: 31415
  nodePort: 31415

persistence:
  enabled: true
  storageClass: "nfs-client"
  accessMode: ReadWriteMany
  size: 1Gi
  mountPath: /app/dummy-data

resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"

EOF

# nfs-pv.yaml
cat <<'EOF' >/home/ubuntu/helm/nfs-pv.yaml
# NFS StorageClass and PersistentVolume for ITAM application
apiVersion: v1
kind: PersistentVolume
metadata:
  name: itam-nfs-pv
  labels:
    type: nfs
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs-client
  nfs:
    path: /srv/nfs/k8s
    server: 10.0.1.10

---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-client
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: Immediate

EOF

# templates/deployment.yaml
cat <<'EOF' >/home/ubuntu/helm/templates/deployment.yaml
# Deployment for ITAM Flask application
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Chart.Name }}
  labels:
    app: {{ .Chart.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Chart.Name }}
  template:
    metadata:
      labels:
        app: {{ .Chart.Name }}
    spec:
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      containers:
      - name: {{ .Chart.Name }}
        image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - containerPort: {{ .Values.service.port }}
          name: http
        env:
        - name: ITAM_DATA_DIR
          value: {{ .Values.persistence.mountPath }}
        - name: PORT
          value: "{{ .Values.service.port }}"
        - name: FLASK_DEBUG
          value: "False"
        volumeMounts:
        - name: data
          mountPath: {{ .Values.persistence.mountPath }}
        resources:
          {{- toYaml .Values.resources | nindent 10 }}
      volumes:
      - name: data
        {{- if .Values.persistence.enabled }}
        persistentVolumeClaim:
          claimName: {{ .Chart.Name }}-pvc
        {{- end }}

EOF

# templates/pvc.yaml
cat <<'EOF' >/home/ubuntu/helm/templates/pvc.yaml
# Persistent Volume Claim for ITAM application data
{{- if .Values.persistence.enabled }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ .Chart.Name }}-pvc
  labels:
    app: {{ .Chart.Name }}
spec:
  accessModes:
    - {{ .Values.persistence.accessMode }}
  storageClassName: {{ .Values.persistence.storageClass }}
  resources:
    requests:
      storage: {{ .Values.persistence.size }}
{{- end }}

EOF

# templates/service.yaml
cat <<'EOF' >/home/ubuntu/helm/templates/service.yaml
# Service for ITAM Flask application
apiVersion: v1
kind: Service
metadata:
  name: {{ .Chart.Name }}
  labels:
    app: {{ .Chart.Name }}
spec:
  type: {{ .Values.service.type }}
  ports:
  - port: {{ .Values.service.port }}
    targetPort: http
    protocol: TCP
    name: http
    {{- if eq .Values.service.type "NodePort" }}
    nodePort: {{ .Values.service.nodePort }}
    {{- end }}
  selector:
    app: {{ .Chart.Name }}

EOF

# deploy.sh
cat <<'EOF' >/home/ubuntu/helm/deploy.sh
#!/bin/bash
# Clean deployment script for ITAM application on Kubernetes
# This script deploys the application without interfering with cluster stability

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check API server connectivity (simple check, no retries)
log_info "Checking Kubernetes API server connectivity..."
if ! kubectl cluster-info &> /dev/null; then
    log_error "Cannot connect to Kubernetes API server"
    log_info "Please ensure:"
    log_info "  1. Cluster is initialized: ls -la /etc/kubernetes/admin.conf"
    log_info "  2. Kubeconfig is set: ls -la ~/.kube/config"
    log_info "  3. API server is running: kubectl get nodes"
    exit 1
fi

log_info "✓ API server is accessible"

# Check if cluster has nodes
log_info "Checking cluster nodes..."
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$NODE_COUNT" -eq 0 ]; then
    log_error "No nodes found in cluster"
    log_info "Please ensure nodes are joined to the cluster"
    exit 1
fi

log_info "✓ Found $NODE_COUNT node(s)"

# Step 1: Deploy NFS PersistentVolume
log_info ""
log_info "Step 1: Deploying NFS PersistentVolume..."

if [ ! -f "nfs-pv.yaml" ]; then
    log_error "nfs-pv.yaml not found in current directory"
    exit 1
fi

kubectl apply -f nfs-pv.yaml

# Wait briefly for PV to be created
sleep 2

PV_STATUS=$(kubectl get pv itam-nfs-pv -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
if [ "$PV_STATUS" = "NotFound" ]; then
    log_warn "PersistentVolume not found, but continuing..."
elif [ "$PV_STATUS" = "Available" ] || [ "$PV_STATUS" = "Bound" ]; then
    log_info "✓ PersistentVolume is ready (status: $PV_STATUS)"
else
    log_warn "PersistentVolume status: $PV_STATUS"
fi

# Step 2: Deploy application
log_info ""
log_info "Step 2: Deploying application..."

if command -v helm &> /dev/null; then
    log_info "Using Helm to deploy..."
    
    if [ ! -f "values.yaml" ]; then
        log_error "values.yaml not found"
        exit 1
    fi
    
    # Deploy with Helm
    helm upgrade --install itam-app . \
        --values values.yaml \
        --timeout 5m \
        --wait=false || {
        log_warn "Helm deployment had issues, but resources may have been created"
    }
    
    log_info "✓ Helm deployment initiated"
else
    log_info "Helm not found, using kubectl..."
    
    if [ ! -d "templates" ]; then
        log_error "templates directory not found"
        exit 1
    fi
    
    # Deploy PVC
    if [ -f "templates/pvc.yaml" ]; then
        kubectl apply -f templates/pvc.yaml
        log_info "✓ PVC applied"
    fi
    
    # Deploy Deployment
    if [ -f "templates/deployment.yaml" ]; then
        kubectl apply -f templates/deployment.yaml
        log_info "✓ Deployment applied"
    fi
    
    # Deploy Service
    if [ -f "templates/service.yaml" ]; then
        kubectl apply -f templates/service.yaml
        log_info "✓ Service applied"
    fi
fi

# Step 3: Wait for deployment (simple wait, no complex checks)
log_info ""
log_info "Step 3: Waiting for deployment to be ready..."

MAX_WAIT=300
ELAPSED=0
READY=false

while [ $ELAPSED -lt $MAX_WAIT ]; do
    # Simple check: are pods running?
    RUNNING_PODS=$(kubectl get pods -l app=itam-app --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l || echo "0")
    TOTAL_PODS=$(kubectl get pods -l app=itam-app --no-headers 2>/dev/null | wc -l || echo "0")
    
    if [ "$TOTAL_PODS" -gt 0 ]; then
        # Check if deployment is ready (if using Helm/Deployment)
        if kubectl wait --for=condition=available deployment/itam-app --timeout=10s &> /dev/null 2>&1; then
            log_info "✓ Deployment is ready!"
            READY=true
            break
        fi
        
        # Show progress
        log_info "Waiting... Running: $RUNNING_PODS/$TOTAL_PODS pods ($ELAPSED/$MAX_WAIT seconds)"
    else
        log_info "Waiting for pods to be created... ($ELAPSED/$MAX_WAIT seconds)"
    fi
    
    sleep 10
    ELAPSED=$((ELAPSED + 10))
done

# Step 4: Show final status
log_info ""
log_info "Deployment Status:"
log_info "================================"

# Show pods
log_info ""
log_info "Pods:"
kubectl get pods -l app=itam-app 2>/dev/null || log_warn "Could not retrieve pods"

# Show service
log_info ""
log_info "Service:"
kubectl get svc itam-app 2>/dev/null || log_warn "Could not retrieve service"

# Show PVC
log_info ""
log_info "PVC:"
kubectl get pvc itam-app-pvc 2>/dev/null || log_warn "Could not retrieve PVC"

# Final message
log_info ""
if [ "$READY" = true ]; then
    log_info "✓ Deployment completed successfully!"
else
    log_warn "Deployment may still be in progress"
    log_info "Check status with: kubectl get pods -l app=itam-app"
fi

log_info ""
log_info "To access the application:"
log_info "  - NodePort: http://<node-ip>:31415"
log_info "  - Get node IPs: kubectl get nodes -o wide"
EOF

# Set permissions for helm folder
chown -R ubuntu:ubuntu /home/ubuntu/helm
chmod 755 /home/ubuntu/helm
chmod 644 /home/ubuntu/helm/*.yaml /home/ubuntu/helm/Chart.yaml 2>/dev/null || true
chmod 755 /home/ubuntu/helm/deploy.sh
chmod 644 /home/ubuntu/helm/templates/*.yaml 2>/dev/null || true
