# ALB
resource "aws_lb" "ITAM-ALB" {
  provider = aws.North-Virginia
  name               = "itam-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ITAM-ALB-SG.id]
  subnets            = [aws_subnet.ITAM-Public-Subnet-1.id, aws_subnet.ITAM-Public-Subnet-2.id]

  enable_deletion_protection = false

  tags = {
    Name = "itam-alb"
  }
}

# Target Group for ALB
resource "aws_lb_target_group" "ITAM-TG" {
  provider = aws.North-Virginia
  name     = "itam-tg"
  port     = 31415  # Flask webserver port
  protocol = "HTTP"
  vpc_id   = aws_vpc.ITAM-VPC.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 10
    path                = "/health"
    protocol            = "HTTP"
    port                = 31415
  }

  tags = {
    Name = "itam-tg"
  }
}

# ALB Listener
resource "aws_lb_listener" "ITAM-ALB-LISTENER" {
  provider = aws.North-Virginia
  load_balancer_arn = aws_lb.ITAM-ALB.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ITAM-TG.arn
  }
}

# Target Group Attachments
# Worker 1
resource "aws_lb_target_group_attachment" "WORKER-1" {
  provider = aws.North-Virginia
  target_group_arn = aws_lb_target_group.ITAM-TG.arn
  target_id        = aws_instance.WORKER-1.id
  port             = 31415
}

# Worker 2
resource "aws_lb_target_group_attachment" "WORKER-2" {
  provider = aws.North-Virginia
  target_group_arn = aws_lb_target_group.ITAM-TG.arn
  target_id        = aws_instance.WORKER-2.id
  port             = 31415
}
