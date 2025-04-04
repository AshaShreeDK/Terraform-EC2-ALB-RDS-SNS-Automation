output "load_balancer_dns_name" {
  value = aws_lb.task15_alb.dns_name
}

output "db_endpoint" {
  value = aws_db_instance.task15_db.address
}

