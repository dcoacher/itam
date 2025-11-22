# SG's
# SG for EC2 instances
resource "aws_security_group" "ITAM-EC2-SG" {
  name        = "itam-ec2-sg"
  description = "SG for EC2 instances"
  vpc_id      = aws_vpc.ITAM-VPC.id

  ingress {
    description = "SSH from allowed IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ip]
  }

  ingress {
    description     = "HTTP from Load Balancer"
    from_port       = 31415
    to_port        = 31415
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

#   ingress {
#     description = "Kubernetes API Server"
#     from_port   = 6443
#     to_port     = 6443
#     protocol    = "tcp"
#     cidr_blocks = [aws_vpc.main.cidr_block]
#   }

#   ingress {
#     description = "NFS"
#     from_port   = 2049
#     to_port     = 2049
#     protocol    = "tcp"
#     cidr_blocks = [aws_vpc.main.cidr_block]
#   }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "itam-ec2-sg"
  }
}

# SG for Load Balancer
resource "aws_security_group" "ITAM-ALB-SG" {
  name        = "itam-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.ITAM-VPC.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "itam-alb-sg"
  }
}