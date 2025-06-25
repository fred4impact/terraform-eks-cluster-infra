output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnet1_id" {
  value = aws_subnet.private_zone1.id
}

output "private_subnet2_id" {
  value = aws_subnet.private_zone2.id
}
