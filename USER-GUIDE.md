# Application User Guide
This guide provides step-by-step instructions for deploying and running the ITAM (IT Asset Management) application.<br>
There are two deployment methods available:
1. **Manual Deployment** - Deploy infrastructure and application manually
2. **CI/CD Deployment** - Automated deployment via GitHub Actions

## Prerequisites
### Required Software (Manual Deployment Method Only)
**Note**: For CI/CD method, you don't need to install any software locally - everything runs in GitHub Actions. You only need a GitHub account and to configure 5 secrets.

For manual deployment method, ensure you have the following installed on your local machine:
1. **Git** - For cloning the repository
2. **Terraform** - For infrastructure provisioning
3. **Docker** or **Docker Desktop** - For building and pushing container images

### AWS Account Requirements
- AWS Access Key ID, Secret Access Key and AWS Session Token:
  - `aws_access_key_id`, `aws_secret_access_key` and `aws_session_token` values is required to set in `terraform.tfvars` file (manual deployment)
  - `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and `AWS_SESSION_TOKEN` will be provisioned to Github Secrets for CI/CD deployment
- Active AWS account with appropriate permissions to create:
  - VPC, Subnets, Internet Gateway
  - EC2 Instances
  - Security Groups
  - Application Load Balancer
  - Key Pairs

### Docker Hub Account
- For manual deployment (used for image pushing to Docker Hub), `docker_repo` value is required to set in `terraform.tfvars` file
- Secrets `DOCKER_USERNAME` and `DOCKER_PASSWORD` provisioning to GitHub (used in CI/CD deployment method)

### GitHub Account
- GitHub account
- Repository access (or fork the repository)

## Method 1: Manual Deployment
1. Start your AWS Academy Sandbox (Architecture Course Lab)
2. Open Visual Studio Code and add clone [GitHub Repository](https://github.com/dcoacher/ITAM/)
3. Open Bash Terminal
4. Build and Push an Application Image to Docker Hub
- Build the image: `docker build -f docker/Dockerfile -t <your_dockerhub_username>/itam-app:latest .`
- Login to Docker Hub: `docker login`
- Push the image: `docker push <your_dockerhub_username>/itam-app:latest`
5. Navigate to the Terraform directory and update the next values in`terraform.tfvars`:
- aws_access_key_id     = `"aws_access_key_id_value"`
- aws_secret_access_key = `"ws_secret_access_key_value"`
- aws_session_token     = `"aws_session_token_value"`
- docker_repo           = `"your_dockerhub_username"`
6. Navigate to `iac/terraform` folder
```bash
cd ./iac/terraform/
```
7. Initialize Terraform
```bash
terraform init
```
This downloads required Terraform providers (AWS provider).
8. Review Infrastructure Plan
```bash
terraform plan
```
9. Apply Infrastructure
```bash
terraform apply -auto-approve
```
10. Wait until infractructure is ready, the process take approximately 5-7 minutes
11. Take a look on Terraform Outputs, you can also copy them
12. SSH to the Control Plane EC2 Instance
```bash
ssh -i KP.pem ubuntu@<control_plane_public_ip>
```
13. Rename Worker 1 EC2 Instance Hostname
```bash
ssh -i KP.pem ubuntu@10.0.1.11 "sudo hostnamectl set-hostname k8s-worker-1"
```
14. Rename Worker 2 EC2 Instance Hostname
```bash
ssh -i KP.pem ubuntu@10.0.2.11 "sudo hostnamectl set-hostname k8s-worker-2"
```
15. Join Worker 1 Instance to K8s Cluster
```bash
ssh -i KP.pem ubuntu@10.0.1.11 "sudo $(cat /home/ubuntu/join-command.sh)"
```
16. Join Worker 2 Instance to K8s Cluster
```bash
ssh -i KP.pem ubuntu@10.0.2.11 "sudo $(cat /home/ubuntu/join-command.sh)"
```
17. Verify that workers were successfully joined K8s cluster
```bash
kubectl get nodes
```
18. Configure NFS client on workers using `Ansible`
```bash
cd ~/ansible
ansible-playbook nfs.yml
```
19. Install an Application on K8s Cluster by Deployment Script using `Helm`
```bash
cd ~/helm
./deploy.sh docker.io/<your_dockerhub_username>/itam-app latest
```
20. Verify Deployment
```bash
# Check pods
kubectl get pods -l app=itam-app

# Check service
kubectl get svc itam-app
```
21. Obtain AWS Load Balancer URL and access the application for further tests performing

## Method 2: CI/CD Deployment
1. Start your AWS Academy Sandbox (Architecture Course Lab)
2. Login to GitHub Account
3. Fork the ITAM Application from [GitHub Repository](https://github.com/dcoacher/ITAM/)
4. Navitage to forked repository `Actions` and click on the `I understand my workflows, go ahead and enable them` button
5. Navigate to `Settings` tab
6. Choose `Secrets and variables` and `Actions`
7. Create the next 5 secrets by clicking on `New repository secret` button:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN`
- `DOCKER_USERNAME`
- `DOCKER_PASSWORD`
8. Trigger CI/CD Pipeline by push or from `Actions` repository section
9. Wait for CI/CD Pipeline to finish
10. Obtain AWS Load Balancer URL and access the application for further tests performing
