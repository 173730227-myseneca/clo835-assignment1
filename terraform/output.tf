output "public_ip" {
  description = "Public IP of EC2"
  value       = aws_instance.assignment1_ec2.public_ip
}