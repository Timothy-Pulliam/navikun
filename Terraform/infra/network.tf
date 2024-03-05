resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
  # DNS support within the VPC
  # second available IP is dedicated to AWS DNS
  # (i.e. 10.0.0.2/16)
  enable_dns_support = true
  # setting to true requires enable_dns_support=true
  enable_dns_hostnames = true
  tags = {
    Name = "vpc-${var.app_name}"
    env  = "dev"
  }
}

resource "aws_subnet" "private1" {
  vpc_id     = aws_vpc.this.id
  cidr_block = "10.0.0.0/24"
  # should instances in this subnet get a 
  # public IP by default?
  map_public_ip_on_launch = false
  availability_zone       = "us-east-1a"
  tags = {
    Name = "snet-${var.app_name}-private-1"
    env  = "dev"
  }
}

resource "aws_subnet" "private2" {
  vpc_id     = aws_vpc.this.id
  cidr_block = "10.0.1.0/24"
  # should instances in this subnet get a 
  # public IP by default?
  map_public_ip_on_launch = false
  availability_zone       = "us-east-1b"
  tags = {
    Name = "snet-${var.app_name}-private-2"
    env  = "dev"
  }
}

resource "aws_subnet" "public1" {
  vpc_id     = aws_vpc.this.id
  cidr_block = "10.0.2.0/24"
  # should instances in this subnet get a 
  # public IP by default?
  map_public_ip_on_launch = false
  availability_zone       = "us-east-1a"
  tags = {
    Name = "snet-${var.app_name}-public-1"
    env  = "dev"
  }
}

resource "aws_subnet" "public2" {
  vpc_id     = aws_vpc.this.id
  cidr_block = "10.0.3.0/24"
  # should instances in this subnet get a 
  # public IP by default?
  map_public_ip_on_launch = false
  availability_zone       = "us-east-1b"
  tags = {
    Name = "snet-${var.app_name}-public-2"
    env  = "dev"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "ig-${var.app_name}-dev"
    env  = "dev"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = {
    Name = "${var.app_name}-public"
  }
}

resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_nat_gateway" "nat_gateway1" {
  depends_on    = [aws_internet_gateway.this]
  allocation_id = aws_eip.nat1.id
  subnet_id     = aws_subnet.public1.id
  tags = {
    Name = "${var.app_name}-natgw-1"
  }
}

resource "aws_nat_gateway" "nat_gateway2" {
  depends_on    = [aws_internet_gateway.this]
  allocation_id = aws_eip.nat2.id
  subnet_id     = aws_subnet.public2.id
  tags = {
    Name = "${var.app_name}-natgw-2"
  }
}

resource "aws_route_table" "private1" {
  depends_on = [aws_internet_gateway.this]
  vpc_id     = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway1.id
  }
  tags = {
    Name = "${var.app_name}-private1"
  }
}

resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private1.id
}

resource "aws_route_table" "private2" {
  depends_on = [aws_internet_gateway.this]
  vpc_id     = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway2.id
  }
  tags = {
    Name = "${var.app_name}-private2"
  }
}

resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private2.id
}

resource "aws_eip" "nat1" {
  depends_on = [aws_internet_gateway.this]
  domain     = "vpc"
  tags = {
    "Name" : "${var.app_name}-nat1-public-ipv4"
  }
}

resource "aws_eip" "nat2" {
  depends_on = [aws_internet_gateway.this]
  domain     = "vpc"
  tags = {
    "Name" : "${var.app_name}-nat2-public-ipv4"
  }
}

# Amazon ECS tasks hosted on Fargate using version 1.4.0 or later require both the com.amazonaws.region.ecr.dkr 
# and com.amazonaws.region.ecr.api Amazon ECR VPC endpoints and the Amazon S3 gateway endpoint.
# https://repost.aws/knowledge-center/ecs-fargate-pull-container-error
# VPC Endpoint for ECR API
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private1.id, aws_subnet.private2.id] # Replace with your subnet IDs
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.private_endpoints.id]

  tags = {
    Name = "ecr-api-endpoint"
  }
}

# VPC Endpoint for ECR Docker Registry
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private1.id, aws_subnet.private2.id] # Replace with your subnet IDs
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.private_endpoints.id] # Optional: Specify if needed

  tags = {
    Name = "ecr-dkr-endpoint"
  }
}

resource "aws_vpc_endpoint" "cloudwatch_endpoint" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private1.id, aws_subnet.private2.id] # Replace with your subnet IDs
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.private_endpoints.id] # Optional: Specify if needed

  tags = {
    Name = "cloudwatch-endpoint"
  }
}

resource "aws_vpc_endpoint" "bedrock_endpoint" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.bedrock-runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private1.id, aws_subnet.private2.id] # Replace with your subnet IDs
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.private_endpoints.id] # Optional: Specify if needed

  tags = {
    Name = "bedrock-runtime-endpoint"
  }
}

resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_vpc.this.default_route_table_id]

  tags = {
    Name = "s3-endpoint"
  }
}
