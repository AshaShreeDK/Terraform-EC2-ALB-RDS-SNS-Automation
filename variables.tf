variable "region" { type = string }
variable "vpc_cidr" { type = string }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
variable "availability_zones" { type = list(string) }
variable "db_username" { type = string }
variable "db_password" { type = string }
variable "db_name" { type = string }
variable "instance_type" { type = string }
variable "base_ami" { type = string }
variable "key_name" { type = string }
variable "desired_capacity" { type = number }
variable "min_size" { type = number }
variable "max_size" { type = number }
variable "notification_email" { type = string }
variable "admin_username" { type = string }
variable "admin_password" { type = string }

