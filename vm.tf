terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region     = var.REGION
  access_key = var.ACCESS_KEY
  secret_key = var.SECRET
}


##Create Amazon VPC(Virtual Private Cloud)
resource "aws_vpc" "tfmyvpc" {
  cidr_block = "172.16.0.0/16"

}

##Create Amazon Subnet within the created VPC
resource "aws_subnet" "tfmysubnet" {
  vpc_id     = aws_vpc.tfmyvpc.id
  cidr_block = "172.16.10.0/24"

}

##Create an network interface inside our subnet, assign the security_groups
resource "aws_network_interface" "tfmynic" {
  subnet_id       = aws_subnet.tfmysubnet.id
  private_ips     = ["172.16.10.100"]
  security_groups = [aws_security_group.tfsg_ssh.id]
}


##Creation of key pairs, it could be created in the EC2 painel aswell
# resource "aws_key_pair" "tfmykey" {
#   key_name   = "deployer-key"
#   public_key = file("./amz_pem.pem")
# }

##Create the network security group, and allow the access to the SSH port
resource "aws_security_group" "tfsg_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.tfmyvpc.id


  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    //cidr_blocks = [aws_vpc.tfmyvpc.cidr_block]
    cidr_blocks = ["0.0.0.0/0"]
  }

  # egress {
  #   from_port   = 0
  #   to_port     = 0
  #   protocol    = "-1"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

}


##Create the EC2 instance itself
resource "aws_instance" "tfmyvm" {
  ami           = "ami-08962a4068733a2b6"
  instance_type = "t2.nano"
  key_name      = "amz_pem" #Already create in KeyPairs(EC2)1

  network_interface {
    network_interface_id = aws_network_interface.tfmynic.id
    device_index         = 0
  }

}

##Create a public ip with amazon elastic ip
resource "aws_eip" "ip-test-env" {
  instance = aws_instance.tfmyvm.id
  vpc      = true
}

##Create a internet gateway so we can receive external requests
resource "aws_internet_gateway" "test-env-gw" {
  vpc_id = aws_vpc.tfmyvpc.id
}

##Route the gateway and our vpc
resource "aws_route_table" "route-table-test-env" {
  vpc_id = aws_vpc.tfmyvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test-env-gw.id
  }
}

#Associate the route with the subnet
resource "aws_route_table_association" "subnet-association" {
  subnet_id      = aws_subnet.tfmysubnet.id
  route_table_id = aws_route_table.route-table-test-env.id
}


output "instance_ips" {
  value = aws_instance.tfmyvm.public_ip
}
