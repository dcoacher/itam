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

variable "docker_repo" {
  description = "Docker Hub username for the container image"
  type        = string
}

# Ansible User-Data Script for K8s Control Plane
locals {
  control_plane_user_data = templatefile("${path.module}/../scripts/user-data-control-plane.sh", {
    docker_username = var.docker_repo
  })
}

# Ansible User-Data Script for K8s Workers
locals {
  worker_user_data = file("${path.module}/../scripts/user-data-worker.sh")
}
