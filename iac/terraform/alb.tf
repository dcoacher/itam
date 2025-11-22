# ALB
resource "aws_lb" "ITAM-ALB" {
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
  name     = "itam-tg"
  port     = 31415  # Flask webserver port
  protocol = "HTTP"
  vpc_id   = aws_vpc.ITAM-VPC.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    port                = 31415
  }

  tags = {
    Name = "itam-tg"
  }
}

# ALB Listener
resource "aws_lb_listener" "ITAM-ALB-LISTENER" {
  load_balancer_arn = aws_lb.ITAM-ALB.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ITAM-TG.arn
  }
}