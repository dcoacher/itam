#!/bin/bash

# Set hostname
hostnamectl set-hostname k8s-controller
add-apt-repository universe
apt update
apt install -y ansible python3 python3-pip python3-venv git

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
control-plane ansible_host=${CONTROL-PLANE-PRIVATE-IP}

[workers]
worker-1 ansible_host=${WORKER-1-PRIVATE-IP}
worker-2 ansible_host=${WORKER-2-PRIVATE-IP}

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

    - name: Add Kubernetes GPG key
      shell: |
        curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
      args:
        creates: /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    - name: Add Kubernetes repository
      lineinfile:
        path: /etc/apt/sources.list.d/kubernetes.list
        line: "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /"
        create: yes
        state: present

    - name: Update apt cache after adding Kubernetes repo
      apt:
        update_cache: yes
        cache_valid_time: 0

    - name: Install Kubernetes packages
      apt:
        name:
          - kubelet={{ kubernetes_version }}
          - kubeadm={{ kubernetes_version }}
          - kubectl={{ kubernetes_version }}
        state: present

    - name: Hold kube packages at current version
      apt:
        name:
          - kubelet
          - kubeadm
          - kubectl
        state: present
        mark_hold: yes

    - name: Enable and start containerd
      systemd:
        name: containerd
        enabled: yes
        state: started

- name: Initialize control-plane node
  hosts: control_plane
  become: yes
  vars:
    kubernetes_version: "1.29.2-00"
    pod_network_cidr: "10.244.0.0/16"
  tasks:
    - name: Initialize Kubernetes control plane
      command: kubeadm init --pod-network-cidr={{ pod_network_cidr }}
      args:
        creates: /etc/kubernetes/admin.conf

    - name: Configure kubeconfig for ubuntu user
      command: "{{ item }}"
      with_items:
        - mkdir -p /home/ubuntu/.kube
        - cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
        - chown ubuntu:ubuntu /home/ubuntu/.kube/config

    - name: Generate join command file
      command: kubeadm token create --print-join-command
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
    nfs_server_ip: "${CONTROL-PLANE-PRIVATE-IP}"
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
