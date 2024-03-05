resource "aws_security_group" "private_endpoints" {
  name        = "allow-https-to-private-endpoints"
  description = "Allow HTTPS inbound"
  vpc_id      = aws_vpc.this.id # Replace with your VPC ID
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "allow-https-to-private-endpoints"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_https1" {
  security_group_id = aws_security_group.private_endpoints.id
  cidr_ipv4         = aws_subnet.private1.cidr_block
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "Allow internal HTTPS traffic to private endpoints"
}

resource "aws_vpc_security_group_ingress_rule" "allow_https2" {
  security_group_id = aws_security_group.private_endpoints.id
  cidr_ipv4         = aws_subnet.private2.cidr_block
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "Allow internal HTTPS traffic to private endpoints"
}

resource "aws_security_group" "alb" {
  name        = "allow-http-from-internet-to-alb"
  description = "Allow HTTP(S) inbound from Internet to ALB"
  vpc_id      = aws_vpc.this.id
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "allow-http-from-internet-to-alb"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "Allow Internet traffic to the ALB"
}

resource "aws_vpc_security_group_ingress_rule" "allow_https_ipv4" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "Allow Internet traffic to the ALB"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4_alb" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


resource "aws_security_group" "ecs_service" {
  name        = "${var.app_name}-ecs-service"
  description = "Security group for containerized ECS Service app"
  vpc_id      = aws_vpc.this.id
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "ECS Service Security Group"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_container" {
  security_group_id            = aws_security_group.ecs_service.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
  description                  = "Allow HTTP traffic from ALB to container port 8080"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_snetprivate1" {
  security_group_id = aws_security_group.ecs_service.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
  description       = "Allow outbound traffic to private subnet"
}

# resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_snetprivate1" {
#   security_group_id = aws_security_group.ecs_service.id
#   cidr_ipv4         = aws_subnet.private1.cidr_block
#   ip_protocol       = "-1" # semantically equivalent to all ports
#   description       = "Allow outbound traffic to private subnet"
# }

# resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_snetprivate2" {
#   security_group_id = aws_security_group.ecs_service.id
#   cidr_ipv4         = aws_subnet.private2.cidr_block
#   ip_protocol       = "-1" # semantically equivalent to all ports
#   description       = "Allow outbound traffic to private subnet"
# }
