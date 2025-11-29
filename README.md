# ITAM (IT Asset Management)
Make your IT Asset Management process simple and controlled. ITAM is a complete web application for tracking computer equipment, software licenses, and accessories in an organization. The application provides a simple and controlled way to manage IT assets, assign items to users, and track inventory status.

<img src="https://cdn3d.iconscout.com/3d/premium/thumb/asset-allocation-3d-icon-download-in-png-blend-fbx-gltf-file-formats--finance-management-8825126.png?f=webp" width="350" height="350" />

## Table Of Contents
1. [Key Features](#1-key-features)<br>
2. [Architecture and Data Structure](#2-architecture-and-data-structure)<br>
    [2.1 Application Stack](#21-application-stack)<br>
    [2.2 High-Level Architecture](#22-high-level-architecture)<br>
    [2.3 Data Structure](#23-data-structure)<br>
3. [Infrastructure Components](#infrastructure-components)<br>
    [3.1 AWS Resources](#31-aws-resources)<br>
    [3.2 Kubernetes Components](#32-kubernetes-components)<br>
    [3.3 NFS](#33-nfs)<br>
4. [Workflow](#4-workflow)<br>
    [4.1 Application](#41-application)<br>
    [4.2 Data Consistency](#42-data-consistency)<br>
    [4.3 CI/CD Pipeline Flow](#43-cicd-pipeline-flow)<br>
    [4.4 Infrastructure as Code](#44-infrastructure-as-code)<br>
    [4.5 Docker Container Details](#45-docker-container-details)<br>
    [4.6 Kubernetes Deployment](#46-kubernetes-deployment)<br>
5. [Deployment Process](#5-deployment-process)<br>
6. [Project Files](#6-project-files)<br>
7. [License](#7-license)<br>
8. [Authors](#8-authors)<br>
9. [Previous Versions](#9-previous-versions)<br>
10. [Feedback](#10-feedback)<br>

## 1. Key Features
- **High Availability**: Multiple application replicas across worker nodes
- **Scalability**: Kubernetes allows easy scaling of pods
- **Persistent Storage**: NFS ensures data persists across pod restarts
- **Load Balancing**: ALB distributes traffic across healthy instances
- **Automated Deployment**: CI/CD pipeline automates testing, building, and deployment
- **Infrastructure as Code**: All infrastructure defined in Terraform
- **Health Monitoring**: Health checks ensure only healthy pods receive traffic

## 2. Architecture and Data Structure
### 2.1 Application Stack
- **Backend**: Flask 3.0.0 (Python 3.11)
- **Web Server**: Gunicorn
- **Frontend**: HTML templates with Bootstrap styling
- **Data Storage**: JSON files stored on NFS shared storage
- **Containerization**: Docker
- **Orchestration**: Kubernetes (K8s), Helm
- **Infrastructure as Code (IaC)**: Terraform, Ansible
- **Cloud Infrastructure**: AWS

### 2.2 High-Level Architecture
```
             🌐Internet 
                  ↓
 ⚖️ Application Load Balancer (ALB) :80
                  ↓
      🎯 Target Group :31415
                  ↓
  🖥️ Worker Node 1 ──→ 📦 Pod 1 (App)
                  ↓
  🖥️ Worker Node 2 ──→ 📦 Pod 2 (App)
                  ↓
       💾 NFS Mount (/mnt/nfs/k8s)
                  ↓
    🎮 Control Plane (k8s-controller)
    ├── ☸️ Kubernetes API Server
    └── 💾 NFS Server (/srv/nfs/k8s)
        └── 📄 users.json, items.json
```

### 2.3 Data Structure
#### Users Data (`users.json`)
Users are stored as a JSON object where each key is a user ID and the value contains user information:

```json
{
  "1": {
    "name": "Brandon Guidelines",
    "items": ["3", "4"]
  },
  "2": {
    "name": "Carnegie Mondover",
    "items": []
  }
}
```

**User Fields:**
- `name`: Full name of the user
- `items`: Array of item IDs assigned to this user

#### Items Data (`items.json`)
Items are stored as a JSON object where each key is an item ID and the value contains item details:

```json
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
  }
}
```

**Item Fields:**
- `id`: Unique item identifier
- `main_category`: Primary category (Assets, Accessories, Licenses)
- `sub_category`: Specific type (Laptop, PC, Mouse, Subscription, etc.)
- `manufacturer`: Manufacturer name
- `model`: Model name/identifier
- `price`: Item price (numeric)
- `quantity`: Available quantity
- `status`: Current status ("In Stock", "Assigned")
- `assigned_to`: User ID if assigned, `null` if unassigned

## 3. Infrastructure Components
### 3.1 AWS Resources
#### **VPC (Virtual Private Cloud)**
- CIDR: `10.0.0.0/16`
- Provides isolated network environment

#### **Subnets**
- **Public Subnet 1** (`10.0.1.0/24`): Hosts control plane and worker 1
- **Public Subnet 2** (`10.0.2.0/24`): Hosts worker 2
- Both subnets have internet gateway access

#### **Internet Gateway (IGW)**
- Provides internet access to public subnets

#### **EC2 Instances**
- **Control Plane**: `t3.medium` instance
  - Private IP: `10.0.1.10`
  - Hostname: `k8s-controller`
  - Runs Ansible, Kubernetes control plane, NFS server, and Helm charts
- **Worker Node 1**: `t3.medium` instance
  - Private IP: `10.0.1.11`
  - Hostname: `k8s-worker-<instance-id>`
- **Worker Node 2**: `t3.medium` instance
  - Private IP: `10.0.2.11`
  - Hostname: `k8s-worker-<instance-id>`

#### **Security Groups**
- Allows inbound traffic on:
  - Port 22 (SSH)
  - Port 80 (HTTP for ALB)
  - Port 6443 (Kubernetes API)
  - Port 31415 (NodePort service)
  - Port 2049 (NFS)
- Allows all outbound traffic

#### **Application Load Balancer (ALB)**
- Distributes traffic to worker nodes
- Health checks on `/health` endpoint (port 31415)
- Routes HTTP traffic to target group

#### **Target Group**
- Registers worker nodes as targets
- Health check configuration:
  - Path: `/health`
  - Port: 31415
  - Protocol: HTTP
  - Interval: 15s
  - Timeout: 10s
  - Healthy threshold: 2
  - Unhealthy threshold: 3

#### **Key Pair**
- SSH key pair for EC2 instance access
- Private key (`KP.pem`) stored in Terraform state

### 3.2 Kubernetes Components
#### **Control Plane**
- Initialized with `kubeadm init`
- Pod network: Calico CNI (CIDR: `10.244.0.0/16`)
- API server accessible on port 6443

#### **Worker Nodes**
- Joined to cluster using `kubeadm join` command
- Configured with NFS client mounts

#### **Application Deployment**
- **Deployment**: 2 replicas of the Flask application
- **Service**: NodePort type, port 31415
- **PersistentVolume**: NFS-backed, 10Gi
- **PersistentVolumeClaim**: Bound to the NFS PV
- **StorageClass**: `nfs-client` (no-provisioner)

### 3.3 NFS
#### **Server Configuration**
- **Location**: Control plane node (`10.0.1.10`)
- **Export Path**: `/srv/nfs/k8s`
- **Export Configuration**: Accessible to `10.0.0.0/16` (entire VPC)

#### **Client Configuration**
- **Mount Point**: `/mnt/nfs/k8s` (on worker nodes)
- **Server**: `10.0.1.10:/srv/nfs/k8s`
- **Configured by**: Ansible playbook (`nfs.yml`)

## 4. Workflow
### 4.1 Application
1. **User Request** → ALB receives HTTP request
2. **Load Balancing** → ALB routes to healthy worker node (port 31415)
3. **Kubernetes Service** → NodePort service routes to application pod
4. **Application Pod** → Flask app processes request
5. **Data Access** → Application reads/writes JSON files from NFS mount
6. **Response** → Response sent back through the chain

### 4.2 Data Consistency
- **Multi-Pod Consistency**: All pods mount the same NFS share
- **Read Strategy**: Data is reloaded from disk on each GET request
- **Write Strategy**: Data is saved immediately to NFS share
- **File Locking**: JSON files are read/written atomically

### 4.3 CI/CD Pipeline Flow
1. **Test Phase**: Runs pytest tests
2. **Build Phase**: Builds Docker image and pushes to Docker Hub
3. **Infrastructure Phase**:
   - Terraform creates/updates AWS infrastructure
   - EC2 instances are provisioned
   - User-data scripts configure Kubernetes
   - Workers join the cluster
   - Ansible configures NFS clients
4. **Deploy Phase**:
   - kubectl configured with cluster access
   - NFS PersistentVolume created
   - Helm deploys application with new image

### 4.4 Infrastructure as Code
#### Terraform
**Purpose**: Provision and manage AWS infrastructure

#### Ansible
**Purpose**: Configures NFS clients on worker nodes

#### User-Data Scripts
- **Control Plane** (`user-data-control-plane.sh`):
  - Installs Kubernetes components (kubeadm, kubelet, kubectl)
  - Initializes Kubernetes cluster
  - Installs Calico CNI
  - Sets up NFS server
  - Creates Helm charts and deployment scripts
  - Configures Ansible for NFS client setup
- **Workers** (`user-data-worker.sh`):
  - Installs Kubernetes components
  - Prepares node for cluster joining (actual join happens via CI/CD)

### 4.5 Docker Container Details
- **Base**: `python:3.11-slim`
- **Dependencies**: Flask 3.0.0, Gunicorn 21.2.0, pytest 8.2.1
- **Port**: 31415
- **Command**: Gunicorn with 4 workers, 2 threads per worker for good performance on production

### 4.6 Kubernetes Deployment
- **Replicas**: 2
- **Resources**:
  - Requests: 128Mi memory, 100m CPU
  - Limits: 256Mi memory, 200m CPU
- **Health Checks**:
  - Readiness: `/health` endpoint, 10s initial delay
  - Liveness: `/health` endpoint, 30s initial delay

## 5. Deployment Process
For Application Deployment please use separate [Application User Guide](https://github.com/dcoacher/ITAM/blob/main/USER-GUIDE.md).

## 6. Project Files
- :file_folder: *`.github`* folder contains CICD workflows
    - :file_folder: *`workflows`* subfolder contains CICD pipelines file
        - :file_folder: *`tests`* subfolder contains test file for CICD process
            - :page_facing_up: *`test_main.py`* test file for CICD pipelines
        - :page_facing_up: *`cicd.yml`* CICD pipelines
- :file_folder: *`app`* folder contains all application data
    - :file_folder: *`dummy-data`* subfolder contains dummy data JSON files
        - :page_facing_up: *`items.json`* items dummy data JSON file
        - :page_facing_up: *`users.json`* users dummy data JSON file
    - :file_folder: *`website`* subfolder contains pre-rendered .html pages for the website
        - :page_facing_up: *`add_item.html`*
        - :page_facing_up: *`add_user.html`*
        - :page_facing_up: *`assign_item.html`*
        - :page_facing_up: *`base.html`*
        - :page_facing_up: *`delete_item.html`*
        - :page_facing_up: *`index.html`*
        - :page_facing_up: *`modify_item_form.html`* 
        - :page_facing_up: *`modify_item_select.html`*
        - :page_facing_up: *`show_stock_items.html`* 
        - :page_facing_up: *`show_user_items_select.html`*
        - :page_facing_up: *`show_user_items.html`*
        - :page_facing_up: *`show_users.html`*
        - :page_facing_up: *`stock_by_categoeirs.html`*
    - :page_facing_up: *`app.py`* main application file
    - :page_facing_up: *`storage.py`* storage file for operating with persistent storage
- :file_folder: *`docker`* folder contains Docker deployment data
    - :page_facing_up: *`Dockerfile`* configuration file for Docker environment
- :file_folder: *`iac`* folder contains IaC deployment data
    - :file_folder: *`scripts`* subfolder contains user data scripts for control plane and workers deployment
        - :page_facing_up: *`user-data-control-plane.sh`*
        - :page_facing_up: *`user-data-worker.sh`*
    - :file_folder: *`terraform`* subfolder contains AWS deployment data
        - :page_facing_up: *`alb.tf`* Load Balancer
        - :page_facing_up: *`ec2.tf`* EC2 instances
        - :page_facing_up: *`keypair.tf`* Keypair
        - :page_facing_up: *`network.tf`* Network (VPC, Subnets, IGW, Routes)
        - :page_facing_up: *`outputs.tf`* AWS Environment Outputs Data
        - :page_facing_up: *`providers.tf`* Terraform Providers
        - :page_facing_up: *`sg.tf`* Security Groups
        - :page_facing_up: *`terraform.tfvars`* Terraform Tfvars
        - :page_facing_up: *`variables.tf`* Terraform Variables
- :page_facing_up: *`LICENSE`* License Information
- :page_facing_up: *`README.md`* Readme File
- :page_facing_up: *`USER-GUIDE.md`* Application Usage User Guide

## 7. License
[![GPLv3 License](https://img.shields.io/badge/License-GPL%20v3-yellow.svg)](https://github.com/dcoacher/ITAM/blob/main/LICENSE)

## 8. Authors
- Desmond Coacher - [@dcoacher](https://github.com/dcoacher)

## 9. Previous Versions
**Name:** [IT Asset Management](https://github.com/dcoacher/it-asset-management)<br>
**Version:** 1.0<br>
**Release date:** July 28, 2025

## 10. Feedback
If you have any feedback, feel free to contact us via email: 
- [Desmond Coacher](mailto:dcoacher@outlook.com)
