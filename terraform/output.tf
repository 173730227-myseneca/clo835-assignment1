output "public_ip" {
  description = "Public IP of EC2"
  value       = aws_instance.assignment1_ec2.public_ip
}

output "loadbalancer_dns" {
  description = "DNS of ALB"
  value       = aws_lb.app_alb.dns_name
}