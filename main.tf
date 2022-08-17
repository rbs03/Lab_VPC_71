terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
  region     = var.region
}

//VPC
resource "aws_vpc" "practical7_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name = "new_vpc"
  }
}
resource "aws_eip" "lab_epi" {
  vpc = true
}

//Subnet Group
resource "aws_subnet" "Public1_subnet1" {
  vpc_id            = aws_vpc.practical7_vpc.id
  availability_zone = "us-east-1a"
  cidr_block        = "10.0.0.0/24"
}

//Subnet Group
resource "aws_subnet" "Private1_subnet1" {
  vpc_id            = aws_vpc.practical7_vpc.id
  availability_zone = "us-east-1a"
  cidr_block        = "10.0.1.0/24"
}

resource "aws_internet_gateway" "igw1" {
  vpc_id = aws_vpc.practical7_vpc.id

  tags = {
    Name = "newInternetGateway"
  }

}
resource "aws_nat_gateway" "newGateway" {
  allocation_id     = aws_eip.lab_epi.id
  subnet_id         = aws_subnet.Public1_subnet1.id
  connectivity_type = "public"

  tags = {
    Name = "gw NAT"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw1]
}


resource "aws_route_table" "lab_public_route_table" {
  vpc_id = aws_vpc.practical7_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw1.id
  }
  tags = {
    Name = "Public Route Table"
  }
}

resource "aws_route_table" "lab_private_route_table" {
  vpc_id = aws_vpc.practical7_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.newGateway.id
  }
  tags = {
    Name = "Private Route Table"
  }
}

resource "aws_route_table_association" "public_sub_association" {
  subnet_id      = aws_subnet.Public1_subnet1.id
  route_table_id = aws_route_table.lab_public_route_table.id
}

resource "aws_route_table_association" "private_sub_assocication" {
  subnet_id      = aws_subnet.Private1_subnet1.id
  route_table_id = aws_route_table.lab_private_route_table.id
}

resource "aws_security_group" "sg_pub_vm" {
  vpc_id = aws_vpc.practical7_vpc.id
  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name = "Public Host SG"
  }
}





resource "aws_security_group" "sg_pvt_vm" {
  vpc_id = aws_vpc.practical7_vpc.id
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.sg_pub_vm.id]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name = "Private Host SG"
  }
}




//EC2 INSTANCE
resource "aws_instance" "private_server" {
  ami             = "ami-052efd3df9dad4825"
  instance_type   = "t2.micro"
  key_name        = "key1"
  security_groups = [aws_security_group.sg_pvt_vm.id]
  subnet_id       = aws_subnet.Private1_subnet1.id
  associate_public_ip_address = true
  tags = {
    Name = "private_server"
  }
}

//EC2 INSTANCE
resource "aws_instance" "public_server" {
  ami             = "ami-052efd3df9dad4825"
  instance_type   = "t2.micro"
  key_name        = "key1"
  security_groups = [aws_security_group.sg_pub_vm.id]
  subnet_id       = aws_subnet.Public1_subnet1.id
  associate_public_ip_address = true

  tags = {
    Name = "public_server"
  }
}