# KeyPair

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

# KP Copying from Terraform to Ansible Control VM
resource "terraform_data" "Key_Pair_Copy" {
  # Recreate this resource (and rerun provisioners) whenever the local key changes
  triggers_replace = {
    key_checksum = sha256(file("${path.module}/KP.pem"))
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
    source      = "${path.module}/KP.pem"
    destination = "/home/ubuntu/KP.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /home/ubuntu/KP.pem",
      "chown ubuntu:ubuntu /home/ubuntu/KP.pem"
    ]
  }

}
