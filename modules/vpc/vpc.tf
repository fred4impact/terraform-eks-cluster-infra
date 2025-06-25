#VPC
resource "aws_vpc" "main" {
  cidr_block = var.cidr_block

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.env}-main"
  }
}

#AMI
data "aws_ami" "ubuntu_ami" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

data "http" "my_ip" {
  url = "http://checkip.amazonaws.com"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

#SECURITY GROUP
resource "aws_security_group" "dev" {
  name_prefix = "${var.project_name}-dev-"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Jenkins"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SonarQube"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Nexus"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-dev-sg"
  }
}

#EC2
resource "aws_instance" "dev" {
  ami                    = data.aws_ami.ubuntu_ami.id
  instance_type          = "t2.xlarge"
  key_name               = var.key_pair_name
  subnet_id              = aws_subnet.public_zone1.id
  vpc_security_group_ids = [aws_security_group.dev.id]

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/tools-install.sh", {
    cluster_name = var.project_name
    region       = var.region
  })

  tags = {
    Name = "${var.project_name}-dev"
  }
}

#ECR
resource "aws_ecr_repository" "backend" {
  name                 = "backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name        = "backend"
    Environment = "dev"
    Project     = "mtire"
  }
}

resource "aws_ecr_repository" "frontend" {
  name                 = "frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name        = "frontend"
    Environment = "dev"
    Project     = "mtire"
  }
}

#INTERNET GATEWAY 
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    "Name" = "${var.env}-igw"
  }
}


#LASTIC IP
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.env}-nat"
  }
}

#NAT GATEWAY 
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_zone1.id

  tags = {
    Name = "${var.env}-nat"
  }

  depends_on = [aws_internet_gateway.igw]
}

#ROUTE TABLE
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.env}-private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.env}-public"
  }
}

resource "aws_route_table_association" "private_zone1" {
  subnet_id      = aws_subnet.private_zone1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_zone2" {
  subnet_id      = aws_subnet.private_zone2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "public_zone1" {
  subnet_id      = aws_subnet.public_zone1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_zone2" {
  subnet_id      = aws_subnet.public_zone2.id
  route_table_id = aws_route_table.public.id
}

#SUBNETS
resource "aws_subnet" "private_zone1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.0.0/19"
  availability_zone = var.zone1

  tags = {

    "Name"                                             = "${var.env}-Private-${var.zone1}"
    "kubernetes.io/role/internal-elb"                  = "1"
    "kubernetes.io/cluster/${var.env}-${var.eks_name}" = "owned"
  }
}


resource "aws_subnet" "private_zone2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.32.0/19"
  availability_zone = var.zone2

  tags = {

    "Name"                                             = "${var.env}-Private-${var.zone2}"
    "kubernetes.io/role/internal-elb"                  = "1"
    "kubernetes.io/cluster/${var.env}-${var.eks_name}" = "owned"
  }
}

resource "aws_subnet" "public_zone1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.64.0/19"
  availability_zone       = var.zone1
  map_public_ip_on_launch = true

  tags = {

    "Name"                                             = "${var.env}-Public-${var.zone2}"
    "kubernetes.io/cluster/${var.env}-${var.eks_name}" = "owned"
  }
}

resource "aws_subnet" "public_zone2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.96.0/19"
  availability_zone       = var.zone2
  map_public_ip_on_launch = true

  tags = {

    "Name"                                             = "${var.env}-Public-${var.zone2}"
    "kubernetes.io/cluster/${var.env}-${var.eks_name}" = "owned"
  }
}







