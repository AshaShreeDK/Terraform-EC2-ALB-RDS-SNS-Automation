locals {
  app_servers = [
    { name = "task15-app-server1", subnet_id = aws_subnet.task15_public_subnets[0].id },
    { name = "task15-app-server2", subnet_id = aws_subnet.task15_public_subnets[1].id }
  ]
}

resource "aws_vpc" "task15_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "task15-vpc" }
}

resource "aws_internet_gateway" "task15_igw" {
  vpc_id = aws_vpc.task15_vpc.id
  tags = { Name = "task15-igw" }
}

resource "aws_route_table" "task15_public_rt" {
  vpc_id = aws_vpc.task15_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.task15_igw.id
  }

  tags = { Name = "task15-public-rt" }
}

resource "aws_subnet" "task15_public_subnets" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.task15_vpc.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags = { Name = "task15-public-subnet-${count.index + 1}" }
}

resource "aws_route_table_association" "task15_public_assoc" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.task15_public_subnets[count.index].id
  route_table_id = aws_route_table.task15_public_rt.id
}

resource "aws_security_group" "task15_app_sg" {
  vpc_id = aws_vpc.task15_vpc.id

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

  tags = { Name = "task15-app-sg" }
}

resource "aws_security_group" "task15_db_sg" {
  vpc_id = aws_vpc.task15_vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.task15_app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "task15-db-sg" }
}

resource "aws_db_subnet_group" "task15_db_subnet_group" {
  name       = "task15-db-subnet-group"
  subnet_ids = aws_subnet.task15_public_subnets[*].id
  tags = { Name = "task15-db-subnet-group" }
}

resource "aws_db_instance" "task15_db" {
  identifier             = "task15-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  allocated_storage      = 20
  db_subnet_group_name   = aws_db_subnet_group.task15_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.task15_db_sg.id]
  skip_final_snapshot    = true
  tags = { Name = "task15-db" }
}

resource "aws_instance" "task15_app" {
  for_each = { for index, server in local.app_servers : index => server }

  ami                    = var.base_ami
  instance_type          = var.instance_type
  subnet_id              = each.value.subnet_id
  vpc_security_group_ids = [aws_security_group.task15_app_sg.id]
  key_name               = var.key_name

  user_data = <<EOF
#!/bin/bash
yum update -y
amazon-linux-extras enable php8.0
yum install -y httpd
systemctl start httpd
echo "Task15 Application Server" > /var/www/html/index.html
echo "Hostname: $(hostname)" >> /var/www/html/index.html
echo "Database Host: ${aws_db_instance.task15_db.address}" >> /var/www/html/index.html
echo "Database User: ${var.db_username}" >> /var/www/html/index.html
echo "Database Password: ${var.db_password}" >> /var/www/html/index.html
systemctl enable httpd
EOF

  tags = {
    Name = each.value.name
  }
}
resource "aws_lb" "task15_alb" {
  name               = "task15-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.task15_public_subnets[*].id
  tags = { Name = "task15-alb" }
}

resource "aws_lb_target_group" "task15_tg" {
  name     = "task15-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.task15_vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = { Name = "task15-tg" }
}

resource "aws_lb_listener" "task15_listener" {
  load_balancer_arn = aws_lb.task15_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.task15_tg.arn
  }
}

resource "aws_launch_template" "task15_lt" {
  name_prefix            = "task15-app-lt"
  image_id               = var.base_ami
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.task15_app_sg.id]
  user_data              = base64encode(<<EOF
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo "Task15 Application Server" > /var/www/html/index.html
echo "Database Host: ${aws_db_instance.task15_db.address}" >> /var/www/html/index.html
echo "Database User: ${var.admin_username}" >> /var/www/html/index.html
echo "Database Password: ${var.admin_password}" >> /var/www/html/index.html
EOF
  )
  tag_specifications {
    resource_type = "instance"
    tags = { Name = "task15-app-instance" }
  }
}

resource "aws_autoscaling_group" "task15_asg" {
  desired_capacity    = var.desired_capacity
  max_size            = var.max_size
  min_size            = var.min_size
  vpc_zone_identifier = aws_subnet.task15_public_subnets[*].id
  target_group_arns   = [aws_lb_target_group.task15_tg.arn]
  launch_template {
    id      = aws_launch_template.task15_lt.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "task15-asg-instance"
    propagate_at_launch = true
  }
  depends_on = [aws_lb_listener.task15_listener]
}

resource "aws_sns_topic" "task15_sns" {
  name = "task15-sns-topic"
}

resource "aws_sns_topic_subscription" "task15_email_subscription" {
  topic_arn = aws_sns_topic.task15_sns.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_autoscaling_notification" "task15_asg_notification" {
  group_names   = [aws_autoscaling_group.task15_asg.name]
  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR"
  ]
  topic_arn = aws_sns_topic.task15_sns.arn
}

