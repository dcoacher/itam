# Outputs

output "control_plane_ip" {
  description = "Control Plane Public IP"
  value       = aws_instance.control_plane.public_ip
}

output "worker_1_ip" {
  description = "Worker 1 Public IP"
  value       = aws_instance.worker_1.public_ip
}

output "worker_2_ip" {
  description = "Worker 2 Public IP"
  value       = aws_instance.worker_2.public_ip
}

output "alb_dns_name" {
  description = "ALB DNS Name"
  value       = aws_lb.main.dns_name
}

output "control_plane_private_ip" {
  description = "Control Plane Private IP"
  value       = aws_instance.control_plane.private_ip
}

output "worker_1_private_ip" {
  description = "Worker 1 Private IP"
  value       = aws_instance.worker_1.private_ip
}

output "worker_2_private_ip" {
  description = "Worker 2 Private IP"
  value       = aws_instance.worker_2.private_ip
}
