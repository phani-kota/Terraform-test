provider "aws" {
  profile                 = "default"
  region                  = "us-east-2"    
}

resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"

  tags = {
    "Terraform" = "true"
    }
}

resource "aws_subnet" "default_az1" {
  vpc_id     = aws_vpc.default.id
  cidr_block = "10.0.1.0/24"

  tags = {
    "Terraform" = "true"
  }
}

resource "aws_instance" "web" {
  ami          		 = "ami-056f139b85f494248"
  instance_type 	 = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_tls.id]

  tags = {
    "Terraform" = "true"
  }
}

resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow standard http and https inbound and everything outbound"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.default.cidr_block]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.default.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

resource "aws_eip" "lb" {
  instance = aws_instance.web.id
  vpc      = true
}

resource "aws_db_instance" "default" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  name                 = "mysqldb"
  username             = "phani"
  password             = "phani123"
  parameter_group_name = "default.mysql5.7"
}
