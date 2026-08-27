variable "aws_region" {
  description = "AWS region these resources are created in."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Identifier for the project. Applied as the Project tag and used in resource naming."
  type        = string
  default     = "realworld-aws"
}

variable "environment" {
  description = "Logical environment these resources belong to, applied as the Environment tag."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner tag."
  type        = string
  default     = "platform-team"
}

variable "cost_center" {
  description = "CostCenter tag, so spend can be attributed in cost reports."
  type        = string
  default     = "engineering"
}

# dev gets 10.0.0.0/16; if prod is ever built it should use a non-overlapping range like 10.1.0.0/16
variable "vpc_cidr_block" {
  description = "CIDR block for the dev VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs, one per AZ."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "Private-app subnet CIDRs, one per AZ."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "private_db_subnet_cidrs" {
  description = "Private-db subnet CIDRs, one per AZ."
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

variable "flow_log_retention_days" {
  description = "CloudWatch retention for VPC flow logs, in days. Short in dev to keep cost down."
  type        = number
  default     = 1
}

# dev-only IP restriction - widen to 0.0.0.0/0 when actually going live
variable "alb_ingress_cidr" {
  description = "CIDR allowed to reach alb-sg on 80/443."
  type        = string
  default     = "109.245.225.55/32"
}

variable "alb_to_node_ports" {
  description = "Ports the alb's ip-mode target groups reach on node-sg."
  type        = list(number)
  default     = [8080, 8081]
}
