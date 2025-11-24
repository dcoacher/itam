# Variables

variable "aws_region" {
  description = "AWS Region for All Resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_access_key_id" {
  description = "AWS Access Key ID"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key"
  type        = string
  sensitive   = true
}

variable "aws_session_token" {
  description = "AWS Session Token"
  type        = string
  sensitive   = true
}

variable "ami_id" {
  description = "AMI for EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

# variable "allowed_ip" {
#   description = "Your IP address, allowed for SSH access"
#   type        = string
# }

# Ansible User-Data Script for K8s Control Plane
locals {
  ansible_control_plane_user_data = file("${path.module}/../ansible/user-data.sh")
}
