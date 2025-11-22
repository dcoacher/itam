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
  key_name   = "itam-keypair"
  public_key = tls_private_key.ITAM-KP.public_key_openssh

  tags = {
    Name = "itam-keypair"
  }
}
