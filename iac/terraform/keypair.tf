# KP Creation and Deployment
# By default lines 30-65 are commented. 
# After first Terraform Env Deployment, uncomment those lines and deploy again.
# KP.pem wil be copied to the Ansible & K8s Control Plane EC2 Machine

# TLS Private Key Generation
resource "tls_private_key" "ITAM-KP" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key to KP.pem file locally
resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.ITAM-KP.private_key_pem
  filename        = "${path.module}/KP.pem"
  file_permission = "0600"
}

# Create AWS key pair from the generated public key
resource "aws_key_pair" "ITAM-KP" {
  provider = aws.North-Virginia
  key_name   = "itam-keypair"
  public_key = tls_private_key.ITAM-KP.public_key_openssh

  tags = {
    Name = "itam-keypair"
  }
}

# KP Copying from Terraform to Control Plane
resource "terraform_data" "KP-Copy" {
  # Recreate this resource (and rerun provisioners) whenever the local key changes
  triggers_replace = {
    key_checksum = sha256(tls_private_key.ITAM-KP.private_key_pem)
    control_plane_ip = aws_instance.CONTROL-PLANE.public_ip
  }

  # One connection for all provisioners
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.ITAM-KP.private_key_pem
    host        = aws_instance.CONTROL-PLANE.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/ubuntu/",
      "chmod 700 /home/ubuntu/",
      "chown ubuntu:ubuntu /home/ubuntu/"
    ]
  }

  provisioner "file" {
    content     = tls_private_key.ITAM-KP.private_key_pem
    destination = "/home/ubuntu/KP.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /home/ubuntu/KP.pem",
      "chown ubuntu:ubuntu /home/ubuntu/KP.pem"
    ]
  }

  depends_on = [aws_instance.CONTROL-PLANE]
}
