# START OF ENVIRONMENT SETUP FOR PROJECT A


# Creating the VPC for the workshop
# This is where all our resources for Project A will be provisioned
# Essentially reserves the private range of 10.0.0.0 to 10.0.255.255 for our cloud resources
# Equates to about 65,536 addresses in total
resource "aws_vpc" "workshop-vpc" {
  cidr_block = "10.0.0.0/16"
}

# Within the VPC, create the East-1a Subnet
# The subnet would have 2^(32 - 24) - 5 = 2^8 - 5 = 256 - 5 = 251 usable private IP address
# NOTE: For AWS, the first 4 and last IP address of a subnet is unusable
# The usable range: 10.0.1.4 to 10.0.1.254

resource "aws_subnet" "east-1a-subnet" {
  vpc_id = aws_vpc.workshop-vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true

  # Subnet and all resources inside will be associated with the zone of us-east-1a
  availability_zone = "us-east-1a"

  tags = {
    Name = "east-1a-subnet"
  }
}

# Within the VPC, create the East-1b Subnet
# The subnet would have 2^(32 - 24) - 5 = 2^8 - 5 = 256 - 5 = 251 usable private IP address
# NOTE: For AWS, the first 4 and last IP address of a subnet is unusable
# The usable range: 10.0.2.4 to 10.0.2.254
resource "aws_subnet" "east-1b-subnet" {
  vpc_id = aws_vpc.workshop-vpc.id
  cidr_block = "10.0.2.0/24"
  map_public_ip_on_launch = true

  # Subnet and all resources inside will be associated with the zone of us-east-1b
  availability_zone = "us-east-1b"

  tags = {
    Name = "east-1b-subnet"
  }
}

# Creating the Internet Gateway
# This will allow our resources in both subnets to gain internet access = Basically turning our subnets into public subnets
resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = aws_vpc.workshop-vpc.id
}

# Creating the Route Table for both subnets
# We will add the route of 0.0.0.0/0 to the internet gateway
# Essentially, this is a catch all statement to send all traffic intended for the internet to the internet gateway
resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.workshop-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gateway.id
  }
}

# Route table asssociation
# Attaching route table to east-1a subnet
resource "aws_route_table_association" "rt1" {
  subnet_id = aws_subnet.east-1a-subnet.id
  route_table_id = aws_route_table.route_table.id
}

# Route table asssociation
# Attaching route table to east-1b subnet
resource "aws_route_table_association" "rt2" {
  subnet_id = aws_subnet.east-1b-subnet.id
  route_table_id = aws_route_table.route_table.id
}

# Workshop Security Group
# This security group will allow all inbound http, https and ssh traffic
# It will also allow all outbound Ipv4 traffic
resource "aws_security_group" "workshop_sg" {
  name        = "Workshop Security Group"
  description = "Workshop Security Group"
  vpc_id      = aws_vpc.workshop-vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
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