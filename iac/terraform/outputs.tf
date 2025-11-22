# Outputs

output "control_plane_ip" {
  description = "Control Plane Public IP"
  value       = aws_instance.CONTROL-PLANE.public_ip
}

output "worker_1_ip" {
  description = "Worker 1 Public IP"
  value       = aws_instance.WORKER-1.public_ip
}

output "worker_2_ip" {
  description = "Worker 2 Public IP"
  value       = aws_instance.WORKER-2.public_ip
}

output "alb_dns_name" {
  description = "ALB DNS Name"
  value       = aws_lb.ITAM-ALB.dns_name
}

output "control_plane_private_ip" {
  description = "Control Plane Private IP"
  value       = aws_instance.CONTROL-PLANE.private_ip
}

output "worker_1_private_ip" {
  description = "Worker 1 Private IP"
  value       = aws_instance.WORKER-1.private_ip
}

output "worker_2_private_ip" {
  description = "Worker 2 Private IP"
  value       = aws_instance.WORKER-2.private_ip
}
