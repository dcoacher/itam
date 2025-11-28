#!/bin/bash
hostnamectl set-hostname k8s-controller
apt update
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab
echo "overlay" > /etc/modules-load.d/k8s.conf
echo "br_netfilter" >> /etc/modules-load.d/k8s.conf
modprobe overlay
modprobe br_netfilter
cat <<SYSCTL | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
SYSCTL
sysctl --system
apt install -y containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd
apt install -y apt-transport-https ca-certificates curl gpg
KUBE_VERSION=$(curl -s https://api.github.com/repos/kubernetes/kubernetes/releases/latest | grep tag_name | cut -d '"' -f 4 | cut -d 'v' -f 2 | cut -d '.' -f 1,2)
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v$${KUBE_VERSION}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$${KUBE_VERSION}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
apt update
apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
apt install -y awscli ansible python3 python3-pip python3-venv git
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
sleep 30
kubeadm init --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors=Mem --cri-socket unix:///var/run/containerd/containerd.sock
mkdir -p /home/ubuntu/.kube
cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config
chmod 600 /home/ubuntu/.kube/config
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml
kubeadm token create --print-join-command > /home/ubuntu/join-command.sh
chmod 755 /home/ubuntu/join-command.sh
chown ubuntu:ubuntu /home/ubuntu/join-command.sh
apt install -y nfs-kernel-server
mkdir -p /srv/nfs/k8s
chmod 777 /srv/nfs/k8s
echo "/srv/nfs/k8s 10.0.0.0/16(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
exportfs -ra
systemctl restart nfs-kernel-server
systemctl enable nfs-kernel-server
cat <<'EOF' >/srv/nfs/k8s/items.json
{
  "1": {
    "id": "1",
    "main_category": "Assets",
    "sub_category": "Laptop",
    "manufacturer": "Dell",
    "model": "XPS",
    "price": 5000,
    "quantity": 1,
    "status": "In Stock",
    "assigned_to": null
  },
  "2": {
    "id": "2",
    "main_category": "Assets",
    "sub_category": "Laptop",
    "manufacturer": "Lenovo",
    "model": "X1 Carbon",
    "price": 8300,
    "quantity": 1,
    "status": "In Stock",
    "assigned_to": null
  },
  "3": {
    "id": "3",
    "main_category": "Assets",
    "sub_category": "PC",
    "manufacturer": "Asus",
    "model": "Desktop Intel Core i9 14900KS",
    "price": 14900,
    "quantity": 1,
    "status": "Assigned",
    "assigned_to": "1"
  },
  "4": {
    "id": "4",
    "main_category": "Accessories",
    "sub_category": "Docking Station",
    "manufacturer": "Dell",
    "model": "WD19TB",
    "price": 700,
    "quantity": 1,
    "status": "Assigned",
    "assigned_to": "1"
  },
  "5": {
    "id": "5",
    "main_category": "Accessories",
    "sub_category": "Mouse",
    "manufacturer": "Logitech",
    "model": "MX Master 3",
    "price": 550,
    "quantity": 1,
    "status": "Assigned",
    "assigned_to": "3"
  },
  "6": {
    "id": "6",
    "main_category": "Licenses",
    "sub_category": "Subscription",
    "manufacturer": "OpenAI",
    "model": "ChatGPT Pro",
    "price": 800,
    "quantity": 1,
    "status": "Assigned",
    "assigned_to": "5"
  }
}
EOF
cat <<'EOF' >/srv/nfs/k8s/users.json
{
  "1": {
    "name": "Brandon Guidelines",
    "items": [
      "3",
      "4"
    ]
  },
  "2": {
    "name": "Carnegie Mondover",
    "items": []
  },
  "3": {
    "name": "John Doe",
    "items": [
      "5"
    ]
  },
  "4": {
    "name": "Abraham Pigeon",
    "items": []
  },
  "5": {
    "name": "Miles Tone",
    "items": [
      "6"
    ]
  },
  "6": {
    "name": "Claire Voyant",
    "items": []
  }
}
EOF
chmod 666 /srv/nfs/k8s/*.json
chown nobody:nogroup /srv/nfs/k8s/*.json
mkdir -p /home/ubuntu/ansible
chown ubuntu:ubuntu /home/ubuntu/ansible
chmod 755 /home/ubuntu/ansible
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
cat <<EOF >/home/ubuntu/ansible/inventory.ini
[control_plane]
control-plane ansible_host="10.0.1.10"
[workers]
worker-1 ansible_host="10.0.1.11"
worker-2 ansible_host="10.0.2.11"
[all:vars]
ansible_python_interpreter=/usr/bin/python3
EOF
cat <<'EOF' >/home/ubuntu/ansible/nfs.yml
- name: Configure NFS clients on workers
  hosts: workers
  become: yes
  vars:
    nfs_export_dir: /srv/nfs/k8s
    nfs_mount_dir: /mnt/nfs/k8s
    nfs_server_ip: "10.0.1.10"
  tasks:
    - apt: name=nfs-common state=present
    - file: path="{{ nfs_mount_dir }}" state=directory mode=0755
    - mount: path="{{ nfs_mount_dir }}" src="{{ nfs_server_ip }}:{{ nfs_export_dir }}" fstype=nfs opts=rw state=mounted
EOF
chown -R ubuntu:ubuntu /home/ubuntu/ansible
chmod 640 /home/ubuntu/ansible/*.yml /home/ubuntu/ansible/inventory.ini /home/ubuntu/ansible/ansible.cfg 2>/dev/null || true
mkdir -p /home/ubuntu/helm/templates
chown ubuntu:ubuntu /home/ubuntu/helm
chmod 755 /home/ubuntu/helm /home/ubuntu/helm/templates
cat <<'EOF' >/home/ubuntu/helm/Chart.yaml
apiVersion: v2
name: itam-app
description: ITAM Flask web application
type: application
version: 1.0.0
appVersion: "1.0"
EOF
cat <<EOF >/home/ubuntu/helm/values.yaml
replicaCount: 2
image:
  repository: docker.io/${docker_username}/itam-app
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
cat <<'EOF' >/home/ubuntu/helm/nfs-pv.yaml
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
cat <<'EOF' >/home/ubuntu/helm/templates/deployment.yaml
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
      nodeSelector:
        node-role.kubernetes.io/worker: "true"
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
        readinessProbe:
          httpGet:
            path: /health
            port: {{ .Values.service.port }}
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 3
        livenessProbe:
          httpGet:
            path: /health
            port: {{ .Values.service.port }}
          initialDelaySeconds: 30
          periodSeconds: 30
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 3
        resources:
          {{- toYaml .Values.resources | nindent 10 }}
      volumes:
      - name: data
        {{- if .Values.persistence.enabled }}
        persistentVolumeClaim:
          claimName: {{ .Chart.Name }}-pvc
        {{- end }}
EOF
cat <<'EOF' >/home/ubuntu/helm/templates/pvc.yaml
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
cat <<'EOF' >/home/ubuntu/helm/templates/service.yaml
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
cat <<'EOF' >/home/ubuntu/helm/deploy.sh
#!/bin/bash
set -euo pipefail
echo "=== ITAM Application Deployment ==="
echo ""
echo "Step 1: Checking Kubernetes API server..."
MAX_WAIT=300
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
  if kubectl cluster-info &>/dev/null 2>&1 && kubectl get nodes &>/dev/null 2>&1; then
    echo "✓ API server is ready"
    break
  fi
  echo "Waiting... ($ELAPSED/$MAX_WAIT seconds)"
  sleep 10
  ELAPSED=$((ELAPSED + 10))
done
if ! kubectl cluster-info &>/dev/null 2>&1; then
  echo "ERROR: Cannot connect to Kubernetes API server"
  exit 1
fi
echo ""
echo "Step 2: Deploying NFS storage..."
kubectl apply -f nfs-pv.yaml
sleep 10
PV_STATUS=$(kubectl get pv itam-nfs-pv -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
echo "PersistentVolume status: $PV_STATUS"
echo ""
echo "Step 3: Deploying application..."
# Accept image parameters (optional, defaults from values.yaml)
IMAGE_REPO="$${1:-}"
IMAGE_TAG="$${2:-}"
if command -v helm &> /dev/null; then
  # Check if Helm release exists
  if helm list -n default | grep -q "itam-app"; then
    echo "Helm release 'itam-app' already exists. Upgrading..."
  else
    echo "Helm release 'itam-app' does not exist. Checking for existing resources..."
    # If resources exist but aren't managed by Helm, delete them so Helm can create fresh
    if kubectl get pvc itam-app-pvc -n default &>/dev/null; then
      MANAGED_BY=$(kubectl get pvc itam-app-pvc -n default -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}' 2>/dev/null || echo "")
      if [ "$MANAGED_BY" != "Helm" ]; then
        echo "Existing PVC found but not managed by Helm. Deleting to allow Helm to create it..."
        # Scale down deployment first to release the PVC
        if kubectl get deployment itam-app -n default &>/dev/null; then
          kubectl scale deployment itam-app -n default --replicas=0 || true
          sleep 5
        fi
        kubectl delete pvc itam-app-pvc -n default --wait=false || true
        sleep 3
      fi
    fi
    # Delete deployment if not managed by Helm
    if kubectl get deployment itam-app -n default &>/dev/null; then
      MANAGED_BY=$(kubectl get deployment itam-app -n default -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}' 2>/dev/null || echo "")
      if [ "$MANAGED_BY" != "Helm" ]; then
        echo "Existing deployment found but not managed by Helm. Deleting..."
        kubectl delete deployment itam-app -n default --wait=false || true
      fi
    fi
    # Delete service if not managed by Helm
    if kubectl get svc itam-app -n default &>/dev/null; then
      MANAGED_BY=$(kubectl get svc itam-app -n default -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}' 2>/dev/null || echo "")
      if [ "$MANAGED_BY" != "Helm" ]; then
        echo "Existing service found but not managed by Helm. Deleting..."
        kubectl delete svc itam-app -n default --wait=false || true
      fi
    fi
    echo "Waiting for resources to be deleted..."
    sleep 5
  fi
  # Deploy with Helm
  if [ -n "$IMAGE_REPO" ] && [ -n "$IMAGE_TAG" ]; then
    echo "Using custom image: $IMAGE_REPO:$IMAGE_TAG"
    helm upgrade --install itam-app . \
      --values values.yaml \
      --set image.repository="$IMAGE_REPO" \
      --set image.tag="$IMAGE_TAG" \
      --set image.pullPolicy=Always \
      --timeout 5m \
      --wait=false
  else
    echo "Using default image from values.yaml"
    helm upgrade --install itam-app . --values values.yaml --timeout 5m --wait=false
  fi
else
  kubectl apply -f templates/pvc.yaml
  kubectl apply -f templates/deployment.yaml
  kubectl apply -f templates/service.yaml
fi
echo ""
echo "Step 4: Waiting for deployment..."
MAX_WAIT=600
ELAPSED=0
READY=false
while [ $ELAPSED -lt $MAX_WAIT ]; do
  if ! kubectl cluster-info &>/dev/null 2>&1; then
    echo "Warning: API server unreachable, retrying..."
    sleep 15
    ELAPSED=$((ELAPSED + 15))
    continue
  fi
  if kubectl wait --for=condition=available deployment/itam-app --timeout=15s &>/dev/null 2>&1; then
    READY=true
    break
  fi
  RUNNING=$(kubectl get pods -l app=itam-app --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l || echo "0")
  TOTAL=$(kubectl get pods -l app=itam-app --no-headers 2>/dev/null | wc -l || echo "0")
  if [ "$TOTAL" -gt 0 ]; then
    echo "Status: $RUNNING/$TOTAL pods running ($ELAPSED/$MAX_WAIT seconds)"
  else
    echo "Waiting for pods... ($ELAPSED/$MAX_WAIT seconds)"
  fi
  sleep 15
  ELAPSED=$((ELAPSED + 15))
done
echo ""
echo "=== Deployment Status ==="
kubectl get pods -l app=itam-app 2>/dev/null || echo "Could not retrieve pods"
echo ""
kubectl get svc itam-app 2>/dev/null || echo "Could not retrieve service"
echo ""
kubectl get pvc 2>/dev/null || echo "Could not retrieve PVC"
echo ""
if [ "$READY" = true ]; then
  echo "✓ Deployment completed successfully"
else
  echo "⚠ Deployment may still be in progress"
  echo "Check status with: kubectl get pods -l app=itam-app"
fi
echo ""
echo "To access the application:"
echo "  - NodePort: http://<node-ip>:31415"
echo "  - Get node IPs: kubectl get nodes -o wide"
EOF
chown -R ubuntu:ubuntu /home/ubuntu/helm
chmod 755 /home/ubuntu/helm /home/ubuntu/helm/deploy.sh
chmod 644 /home/ubuntu/helm/*.yaml /home/ubuntu/helm/Chart.yaml /home/ubuntu/helm/templates/*.yaml 2>/dev/null || true