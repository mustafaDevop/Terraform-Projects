# Output Load Balancer DNS Name
output "load_balancer_dns" {
  value = aws_lb.example_lb.dns_name
}
