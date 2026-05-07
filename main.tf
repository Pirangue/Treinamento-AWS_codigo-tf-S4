terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# --- Rede (simplificada) ---
resource "aws_vpc" "lab" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-ec2-lab"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.lab.id
}

resource "aws_subnet" "publica" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.publica.id
  route_table_id = aws_route_table.rt.id
}

# --- Security Group ---
resource "aws_security_group" "ec2" {
  name   = "ec2-lab"
  vpc_id = aws_vpc.lab.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Key Pair ---
resource "aws_key_pair" "lab" {
  key_name   = "chave-lab-iac"
  public_key = file("~/.ssh/lab-iac.pub")
}

# --- AMI mais recente Amazon Linux 2023 ---
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# --- IAM Role para EC2 ---
resource "aws_iam_role" "ec2_s3_role" {
  name = "ec2-s3-readonly-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_readonly" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-s3-readonly-profile"
  role = aws_iam_role.ec2_s3_role.name
}

# --- EC2 ---
resource "aws_instance" "web" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.publica.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = aws_key_pair.lab.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
    #!/bin/bash
    dnf update -y

    # Nginx
    dnf install -y nginx
    systemctl enable nginx
    systemctl start nginx
    echo "<h1>EC2 via Terraform - IAC AWS</h1>" > /usr/share/nginx/html/index.html

    # Docker
    dnf install -y docker
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user
  EOF

  tags = {
    Name = "ec2-lab-iac"
  }
}

# --- Outputs ---
output "public_ip" {
  value = aws_instance.web.public_ip
}

output "ssh_cmd" {
  value = "ssh -i ~/.ssh/lab-iac ec2-user@${aws_instance.web.public_ip}"
}

output "http_url" {
  value = "http://${aws_instance.web.public_ip}"
}