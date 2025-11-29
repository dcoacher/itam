# EC2
# Control Plane (Public Subnet 1)
resource "aws_instance" "CONTROL-PLANE" {
  provider = aws.North-Virginia
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.ITAM-KP.key_name
  vpc_security_group_ids = [aws_security_group.ITAM-EC2-SG.id]
  subnet_id              = aws_subnet.ITAM-Public-Subnet-1.id
  user_data = local.control_plane_user_data
  private_ip = "10.0.1.10"

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
  user_data = local.worker_user_data
  private_ip = "10.0.1.11"

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
  user_data = local.worker_user_data
  private_ip = "10.0.2.11"

  tags = {
    Name = "itam-worker-2"
    Role = "k8s-worker"
  }
}
