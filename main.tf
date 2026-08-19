data "aws_availability_zones" "available" {
    state = "available"
}

resource "aws_vpc" "main" {
    cidr_block            = "10.0.0.0/16"
    enable_dns_support    = true
    enable_dns_hostnames  = true

    tags = {
        Name = "akuna-web-service-vpc"
    }
}

resource "aws_internet_gateway" "main" {
    vpc_id = aws_vpc.main.id

    tags = {
        Name = "akuna-web-service-igw"
    }
}

resource "aws_subnet" "public_1" {
    vpc_id                  = aws_vpc.main.id
    cidr_block              = "10.0.1.0/24"
    availability_zone       = data.aws_availability_zones.available.names[0]
    map_public_ip_on_launch = true

    tags = {
        Name = "public-subnet-1"
    }
}

resource "aws_subnet" "public_2" {
    vpc_id                  = aws_vpc.main.id
    cidr_block              = "10.0.2.0/24"
    availability_zone       = data.aws_availability_zones.available.names[1]
    map_public_ip_on_launch = true

    tags = {
        Name = "public-subnet-2"
    }
}

resource "aws_subnet" "private_1" {
    vpc_id              = aws_vpc.main.id
    cidr_block          = "10.0.11.0/24"
    availability_zone   = data.aws_availability_zones.names[0]

    tags = {
        Name = "private-subnet-1"
    }
}

resource "aws_subnet" "private_2" {
    vpc_id              = aws_vpc.main.id
    cidr_block          = "10.0.12.0/24"
    availability_zone   = data.aws_availability_zones.available.names[1]

    tags = {
        Name = private-subnet-2"
    }
}

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.main.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.main.id
    }

    tags = {
        Name = "public-route-table"
    }
}

resource "aws_route_table_association" "public_1" {
    subnet_id       = aws_subnet.public_1.id
    route_table_id  = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat_1" {
    domain = "vpc"

    tags = {
        Name = "akuna-nat-eip-1"
    }
}

resource "aws_eip" "nat_2" {
    domain - "vpc"

    tags = {
        Name = "akuna-nat-eip-2"
    }
}

resource "aws_nat_gateway" "nat_1" {
    allocation_id   = aws_eip.nat_1.id
    subnet_id       = aws_subnet.public_1.id

    depends_on = [aws_internet_gateway.main]

    tags = {
        Name = "akuna-nat-gateway-1"
    }
}

resource "aws_nat_gateway" "nat_2" {
    allocation_id   = aws_eip.nat_2.id
    subnet_id       = aws_subnet.public_2.id

    depends_on = [aws_internet_gateway.main]

    tags = {
        Name = "akuna-nat-gateway-2"
    }
}

resource "aws_route_table" "private_1" {
    vpc_id = aws_vpc.main.id

    route {
        cidr_block          = "0.0.0.0/0"
        nat_gateway_id      = aws_nat_gateway.nat_1.id
    }

    tags = {
        Name = "private-rotue-table-1"
    }
}

resource "aws_route_table" "private_2" {
    vpc_id = aws_vpc.main.id

    route {
        cidr_block          = "0.0.0.0/0"
        nat_gateway_id      = aws_nat_gateway.nat_2.id
    }

    tags = {
        Name = "private-route-table-2"
    }
}

resource "aws_route_table_association" "private_1" {
    subnet_id       = aws_subnet.private_1.id
    route_table_id  = aws_route_table.private_1.id
}

resource "aws_route_table_association" "private_2" {
    subnet_id       = aws_subnet.private_2.id
    route_table_id  = aws_route_table.private_2.id
}

resource "aws_security_group" "alb" {
    name        = "akuna-alb-sg"
    description = "allow inbound HTTP traffic to the application load balancer"
    vpc_id      = aws_vpc.main.id

    ingress {
        description = "HTTP from internet"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_block  = ["0.0.0.0/0"]
    }

    egress {
        description = "Allow outbound traffic"
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_block  = ["0.0.0.0/0"]
    }

    tags = {
        Name = "akuna-alb-sg"
    }
}

resource "aws_security_group" "ecs" {
    name        = "akuna-ecs-sg"
    description = "Allow application traffic from the load balancer"
    vpc_id      = aws_vpc.main.id

    ingress {
        description      = "Application traffic from ALB"
        from_port        = 8080
        to_port          = 8080
        protocol         = "tcp"
        security_groups  = [aws_security_group.alb.id]
    }

    egress {
        description = "Allow outbound traffic"
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "akuna-ecs-sg"
    }
}

resource "aws_lb" "app" {
    name               = "akuna-web-service-alb"
    internal           = false
    load_balancer_type = "application"
    security_groups    = [aws_security_group.alb.id]

    subnets = [
        aws_subnet.public_1.id,
        aws_subnet.public_2.id
    ]

    enable_deletion_protection = false

    tags = {
        Name = "akuna-web-service-alb"
    }
}

resource "aws_lb_target_group" "app" {
  name        = "akuna-web-service-tg"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "akuna-web-service-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_ecr_repository" "app" {
    name                    = "akuna-web-service"
    image_tag_mutability    = "MUTABLE"

    image_scanning_configuration {
        scan_on_push = true
    }

    tags = {
        Name = "akuna-web-service"
    }
}

resource "aws_cloudwatch_log_group" "app" {
    name                = "/ecs/akuna-web-service"
    retention_in_days = 30

    tags = {
        Name = "akuna-web-service-logs"
    }
}

resource "aws_ecs_cluster" "main" {
    name = "akuna-web-services-cluster"

    tags = {
        Name = "akuna-web-service-cluster"
    }
}

