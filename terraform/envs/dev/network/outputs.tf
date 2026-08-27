output "vpc_id" {
  description = "ID of the dev VPC."
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the dev VPC."
  value       = module.vpc.vpc_cidr_block
}

output "availability_zones" {
  description = "The 2 AZs used by the dev VPC."
  value       = module.vpc.availability_zones
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway."
  value       = module.vpc.internet_gateway_id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway."
  value       = module.vpc.nat_gateway_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.vpc.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "IDs of the private-app subnets."
  value       = module.vpc.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  description = "IDs of the private-db subnets."
  value       = module.vpc.private_db_subnet_ids
}

output "public_route_table_id" {
  description = "ID of the public route table."
  value       = module.vpc.public_route_table_id
}

output "private_app_route_table_id" {
  description = "ID of the private-app route table."
  value       = module.vpc.private_app_route_table_id
}

output "private_db_route_table_id" {
  description = "ID of the private-db route table (no internet route)."
  value       = module.vpc.private_db_route_table_id
}
