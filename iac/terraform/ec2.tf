# EC2
# Control Plane (Public Subnet 1)
resource "aws_instance" "CONTROL-PLANE" {
  provider = aws.North-Virginia
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.ITAM-KP.key_name
  vpc_security_group_ids = [aws_security_group.ITAM-EC2-SG.id]
  subnet_id              = aws_subnet.ITAM-Public-Subnet-1.id

  user_data = <<-EOF
              set -eux

              # Update system packages
              apt-get update -y

              # Install dependencies for Ansible and tooling
              apt-get install -y \
                python3 \
                python3-pip \
                python3-venv \
                git \
                curl \
                unzip \
                software-properties-common \
                apt-transport-https \
                ca-certificates \
                gnupg \
                lsb-release

              # Install Ansible
              pip3 install --upgrade pip
              pip3 install ansible

              # Prepare workspace for Ansible playbooks
              mkdir -p /home/ubuntu/ansible
              chown ubuntu:ubuntu /home/ubuntu/ansible
              chmod 755 /home/ubuntu/ansible
              EOF

  tags = {
    Name = "itam-control-plane"
    Role = "k8s-control-plane"
  }
}

# Worker Node 1 (Public Subnet 1)
resource "aws_instance" "WORKER-1" {
  provider = aws.North-Virginia
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.ITAM-KP.key_name
  vpc_security_group_ids = [aws_security_group.ITAM-EC2-SG.id]
  subnet_id              = aws_subnet.ITAM-Public-Subnet-1.id

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y python3-pip
              EOF

  tags = {
    Name = "itam-worker-1"
    Role = "k8s-worker"
  }
}

# Worker Node 2 (Public Subnet 2)
resource "aws_instance" "WORKER-2" {
  provider = aws.North-Virginia
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.ITAM-KP.key_name
  vpc_security_group_ids = [aws_security_group.ITAM-EC2-SG.id]
  subnet_id              = aws_subnet.ITAM-Public-Subnet-2.id

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y python3-pip
              EOF

  tags = {
    Name = "itam-worker-2"
    Role = "k8s-worker"
  }
}
