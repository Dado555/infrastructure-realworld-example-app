output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "availability_zones" {
  description = "The 2 AZs this module picked."
  value       = local.azs
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway."
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_id" {
  description = "ID of the single NAT Gateway."
  value       = aws_nat_gateway.this.id
}

output "public_subnet_ids" {
  description = "IDs of the 2 public subnets."
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "IDs of the 2 private-app subnets."
  value       = aws_subnet.private_app[*].id
}

output "private_db_subnet_ids" {
  description = "IDs of the 2 private-db subnets."
  value       = aws_subnet.private_db[*].id
}

output "public_route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}

output "private_app_route_table_id" {
  description = "ID of the private-app route table."
  value       = aws_route_table.private_app.id
}

output "private_db_route_table_id" {
  description = "ID of the private-db route table (no internet route by design)."
  value       = aws_route_table.private_db.id
}

output "node_security_group_id" {
  description = "ID of the EKS node security group."
  value       = aws_security_group.node.id
}

output "rds_security_group_id" {
  description = "ID of the RDS security group."
  value       = aws_security_group.rds.id
}
