# Create vpc
resource "aws_vpc" "Myvpc" {
  cidr_block = var.cidr
}

# Create the subnet1
resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.Myvpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

# Create the subnet1
resource "aws_subnet" "sub2" {
  vpc_id                  = aws_vpc.Myvpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.Myvpc.id
}

# Create RouteTable
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.Myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Create subnet association
resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.sub2.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "web-sg" {
  vpc_id      = aws_vpc.Myvpc.id
  name        = "web-sg"
  description = "Allow inbound traffic for 22 , 80 port and Allow all outbound traffic"

  ingress {
    description = "Allow inbound ssh connection"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow http traffic"
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

  tags = {
    "Name" = "web-sg"
  }
}

# Create s3bucket
resource "aws_s3_bucket" "s3bucket" {
  bucket = "terraform-demo-s3-bucket-xyz"
}

# Create EC2 instance in subnetid 1
resource "aws_instance" "web_server_1" {
  ami                    = "ami-0c7217cdde317cfec"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.sub1.id
  vpc_security_group_ids = [aws_security_group.web-sg.id]
  user_data              = base64encode(file("userdata.sh"))

}

# Create ec2 instance in subnetid 2
resource "aws_instance" "web_server_2" {
  ami                    = "ami-0c7217cdde317cfec"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.sub2.id
  vpc_security_group_ids = [aws_security_group.web-sg.id]
  user_data              = base64encode(file("userdata1.sh"))

}

# Create load balancer
resource "aws_lb" "alb" {
  name               = "alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web-sg.id]
  subnets            = [aws_subnet.sub1.id, aws_subnet.sub2.id]

}

# Create target group
resource "aws_lb_target_group" "tg" {
  name     = "tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.Myvpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }

}

# target attachment
resource "aws_lb_target_group_attachment" "tgattach1" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.web_server_1.id
  port             = 80

}

resource "aws_lb_target_group_attachment" "tgattach2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.web_server_2.id
  port             = 80

}

# Create listener which connects target group with load balancer
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.tg.arn
    type             = "forward"
  }

}

#output to print dns name of the load balancer
output "load_balancer_dns" {
  value = aws_lb.alb.dns_name

}