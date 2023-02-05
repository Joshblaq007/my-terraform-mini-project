provider "aws" {
  region = "us-east-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_vpc" "terraform_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "terraform_vpc"
  }
}

resource "aws_internet_gateway" "terraform-internet-gateway" {
  vpc_id = aws_vpc.terraform_vpc.id

  tags = {
    Name = " terraform IG"
  }
}

resource "aws_route_table" "terraform-public-route-table" {
  vpc_id = aws_vpc.terraform_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terraform-internet-gateway.id
  }
  tags = {
    Name = "terraform-public-route-table"
  }
}

resource "aws_route_table_association" "terraform-public-subnet1-association" {
  subnet_id      = aws_subnet.terraform-public-subnet1.id
  route_table_id = aws_route_table.terraform-public-route-table.id
}

resource "aws_route_table_association" "terraform-public-subnet2-association" {
  subnet_id      = aws_subnet.terraform-public-subnet2.id
  route_table_id = aws_route_table.terraform-public-route-table.id
}

resource "aws_subnet" "terraform-public-subnet1" {
  vpc_id                  = aws_vpc.terraform_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    Name = "terraform-public-subnet1"
  }
}

resource "aws_subnet" "terraform-public-subnet2" {
  vpc_id                  = aws_vpc.terraform_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"
  tags = {
    Name = "terraform-public-subnet2"
  }
}

resource "aws_network_acl" "terraform-network_acl" {
  vpc_id     = aws_vpc.terraform_vpc.id
  subnet_ids = [aws_subnet.terraform-public-subnet1.id, aws_subnet.terraform-public-subnet2.id]


 ingress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
}

resource "aws_security_group" "terraform-load_balancer_sg" {
  name        = "terraform-load-balancer-sg"
  description = "Security group for the load balancer"
  vpc_id      = aws_vpc.terraform_vpc.id

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

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "terraform-security-grp-rule" {
  name        = "allow_ssh_http_https"
  description = "Allow SSH, HTTP and HTTPS inbound traffic for private instances"
  vpc_id      = aws_vpc.terraform_vpc.id

 ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_groups = [aws_security_group.terraform-load_balancer_sg.id]
  }

 ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_groups = [aws_security_group.terraform-load_balancer_sg.id]
  }

  ingress {
    description = "SSH"
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
  tags = {
    Name = "terraform-security-grp-rule"
  }
}

resource "aws_instance" "terraform1" {
  ami             = "ami-00874d747dde814fa"
  instance_type   = "t2.micro"
  key_name        = "terraform-root-server"
  security_groups = [aws_security_group.terraform-security-grp-rule.id]
  subnet_id       = aws_subnet.terraform-public-subnet1.id
  availability_zone = "us-east-1a"
  tags = {
    Name   = "terraform-1"
    source = "terraform"
  }
}

 resource "aws_instance" "terraform2" {
  ami             = "ami-00874d747dde814fa"
  instance_type   = "t2.micro"
  key_name        = "terraform-root-server"
  security_groups = [aws_security_group.terraform-security-grp-rule.id]
  subnet_id       = aws_subnet.terraform-public-subnet2.id
  availability_zone = "us-east-1b"
  tags = {
    Name   = "terraform-2"
    source = "terraform"
  }
}

resource "aws_instance" "terraform3" {
  ami             = "ami-00874d747dde814fa"
  instance_type   = "t2.micro"
  key_name        = "terraform-root-server"
  security_groups = [aws_security_group.terraform-security-grp-rule.id]
  subnet_id       = aws_subnet.terraform-public-subnet1.id
  availability_zone = "us-east-1a"
  tags = {
    Name   = "terraform-3"
    source = "terraform"
  }
}

resource "local_file" "terraform-Ip_address" {
  filename = "/vagrant/terraform/host-inventory"
  content  = <<EOT
${aws_instance.terraform1.public_ip}
${aws_instance.terraform2.public_ip}
${aws_instance.terraform3.public_ip}
  EOT
}

resource "aws_lb" "terraform-load-balancer" {
  name               = "terraform-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.terraform-load_balancer_sg.id]
  subnets            = [aws_subnet.terraform-public-subnet1.id, aws_subnet.terraform-public-subnet2.id]
  #enable_cross_zone_load_balancing = true
  enable_deletion_protection = false
  depends_on                 = [aws_instance.terraform1, aws_instance.terraform2, aws_instance.terraform3]
}

resource "aws_lb_target_group" "terraform-target-group" {
  name     = "terraform-target-group"
  target_type = "instance"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.terraform_vpc.id
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "terraform-listener" {
  load_balancer_arn = aws_lb.terraform-load-balancer.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.terraform-target-group.arn
  }
}

resource "aws_lb_listener_rule" "terraform-listener-rule" {
  listener_arn = aws_lb_listener.terraform-listener.arn
  priority     = 1
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.terraform-target-group.arn
  }
  condition {
    path_pattern {
      values = ["/"]
    }
  }
}

resource "aws_lb_target_group_attachment" "terraform-target-group-attachment1" {
  target_group_arn = aws_lb_target_group.terraform-target-group.arn
  target_id        = aws_instance.terraform1.id
  port             = 80
}
 
resource "aws_lb_target_group_attachment" "terraform-target-group-attachment2" {
  target_group_arn = aws_lb_target_group.terraform-target-group.arn
  target_id        = aws_instance.terraform2.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "terraform-target-group-attachment3" {
  target_group_arn = aws_lb_target_group.terraform-target-group.arn
  target_id        = aws_instance.terraform3.id
  port             = 80 
  
  }

