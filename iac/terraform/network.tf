# Network
# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "ITAM-VPC" {
  cidr_block           = "10.0.0.0/16"
  tags = {
    Name = "itam-vpc"
  }
}

# IGW
resource "aws_internet_gateway" "ITAM-IGW" {
  vpc_id = aws_vpc.ITAM-VPC.id

  tags = {
    Name = "itam-igw"
  }
}

# Public Subnet 1
resource "aws_subnet" "ITAM-Public-Subnet-1" {
  vpc_id                  = aws_vpc.ITAM-VPC.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "itam-public-subnet-1"
  }
}

# Public Subnet 2
resource "aws_subnet" "ITAM-Public-Subnet-2" {
  vpc_id                  = aws_vpc.ITAM-VPC.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "itam-public-subnet-2"
  }
}

# Private Subnet for NFS
resource "aws_subnet" "ITAM-Private-Subnet" {
  vpc_id            = aws_vpc.ITAM-VPC.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "itam-private-subnet"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "ITAM-RT" {
  vpc_id = aws_vpc.ITAM-VPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ITAM-IGW.id
  }

  tags = {
    Name = "itam-public-rt"
  }
}

# Associate Public Subnet 1 with Route Table
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.ITAM-Public-Subnet-1.id
  route_table_id = aws_route_table.ITAM-RT.id
}

# Associate Public Subnet 2 with Route Table
resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.ITAM-Public-Subnet-2.id
  route_table_id = aws_route_table.ITAM-RT.id
}