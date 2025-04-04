region               = "us-east-1"
vpc_cidr             = "10.10.10.0/24"
public_subnet_cidrs  = ["10.10.10.0/28", "10.10.10.16/28"]
private_subnet_cidrs = ["10.10.10.32/28", "10.10.10.48/28"]
availability_zones   = ["us-east-1a", "us-east-1b"]
db_username          = "admin"
db_password          = "admin123"
db_name              = "task15db"
instance_type        = "t2.micro"
base_ami             = "ami-0a9a48ce4458e384e"
key_name             = "asha.nvirg"
desired_capacity     = 2
min_size             = 1
max_size             = 3
notification_email   = "dlrasha14@gmail.com"
admin_username       = "admin"
admin_password       = "admin123"

