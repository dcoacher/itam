# Network
# Data source for availability zones
data "aws_availability_zones" "available" {
  provider = aws.North-Virginia
  state = "available"
}

# VPC
resource "aws_vpc" "ITAM-VPC" {
  provider = aws.North-Virginia
  cidr_block           = "10.0.0.0/16"
  tags = {
    Name = "itam-vpc"
  }
}

# IGW
resource "aws_internet_gateway" "ITAM-IGW" {
  provider = aws.North-Virginia
  vpc_id = aws_vpc.ITAM-VPC.id

  tags = {
    Name = "itam-igw"
  }
}

# Public Subnet 1
resource "aws_subnet" "ITAM-Public-Subnet-1" {
  provider = aws.North-Virginia
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
  provider = aws.North-Virginia
  vpc_id                  = aws_vpc.ITAM-VPC.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "itam-public-subnet-2"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "ITAM-RT" {
  provider = aws.North-Virginia
  vpc_id = aws_vpc.ITAM-VPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ITAM-IGW.id
  }

  tags = {
    Name = "itam-public-rt"
  }
}

# Public 1 RTA
resource "aws_route_table_association" "ITAM-RTA-Public-1" {
  provider = aws.North-Virginia
  subnet_id      = aws_subnet.ITAM-Public-Subnet-1.id
  route_table_id = aws_route_table.ITAM-RT.id
}

# Public 2 RTA
resource "aws_route_table_association" "ITAM-RTA-Public-2" {
  provider = aws.North-Virginia
  subnet_id      = aws_subnet.ITAM-Public-Subnet-2.id
  route_table_id = aws_route_table.ITAM-RT.id
}
