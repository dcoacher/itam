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
# Simple deployment script for ITAM application on Kubernetes

set -e

echo "Deploying ITAM application to Kubernetes..."

# Step 1: Deploy NFS storage
echo "Step 1: Deploying NFS storage..."
kubectl apply -f nfs-pv.yaml

# Check PV status
echo "Checking PersistentVolume status..."
timeout=30
elapsed=0
while [ $elapsed -lt $timeout ]; do
    pv_status=$(kubectl get pv itam-nfs-pv -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    if [ "$pv_status" = "Available" ] || [ "$pv_status" = "Bound" ]; then
        echo "✓ PersistentVolume is ready (status: $pv_status)"
        break
    fi
    if [ "$pv_status" = "NotFound" ]; then
        echo "Waiting for PersistentVolume to be created... ($elapsed/$timeout seconds)"
    else
        echo "Waiting for PersistentVolume to be ready (current status: $pv_status)... ($elapsed/$timeout seconds)"
    fi
    sleep 2
    elapsed=$((elapsed + 2))
done

# Show PV status
echo ""
echo "PersistentVolume status:"
kubectl get pv itam-nfs-pv || echo "Warning: Could not retrieve PV status"

# Step 2: Deploy application using Helm or kubectl
if command -v helm &> /dev/null; then
    echo "Step 2: Deploying application using Helm..."
    helm upgrade --install itam-app . --values values.yaml
else
    echo "Step 2: Deploying application using kubectl..."
    echo "Note: Helm not found, using kubectl instead"
    kubectl apply -f templates/pvc.yaml
    kubectl apply -f templates/deployment.yaml
    kubectl apply -f templates/service.yaml
fi

# Step 3: Wait for deployment
echo "Step 3: Waiting for deployment to be ready..."
kubectl wait --for=condition=available deployment/itam-app --timeout=300s || true

# Step 4: Show status
echo ""
echo "Deployment complete! Status:"
echo "================================"
kubectl get pods -l app=itam-app
echo ""
kubectl get svc itam-app
echo ""
kubectl get pvc

echo ""
echo "To access the application:"
echo "  - NodePort: http://<node-ip>:31415"
echo "  - Get node IPs: kubectl get nodes -o wide"

EOF

# Set permissions for helm folder
chown -R ubuntu:ubuntu /home/ubuntu/helm
chmod 755 /home/ubuntu/helm
chmod 644 /home/ubuntu/helm/*.yaml /home/ubuntu/helm/Chart.yaml 2>/dev/null || true
chmod 755 /home/ubuntu/helm/deploy.sh
chmod 644 /home/ubuntu/helm/templates/*.yaml 2>/dev/null || true
