variable "name_prefix" {
  description = "Prefix applied to resource Name tags and the flow-log group, e.g. realworld-dev."
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the 2 public subnets, one per AZ."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Exactly 2 public subnet CIDRs are required (one per AZ)."
  }
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for the 2 private-app subnets, one per AZ."
  type        = list(string)

  validation {
    condition     = length(var.private_app_subnet_cidrs) == 2
    error_message = "Exactly 2 private-app subnet CIDRs are required (one per AZ)."
  }
}

variable "private_db_subnet_cidrs" {
  description = "CIDR blocks for the 2 private-db subnets, one per AZ."
  type        = list(string)

  validation {
    condition     = length(var.private_db_subnet_cidrs) == 2
    error_message = "Exactly 2 private-db subnet CIDRs are required (one per AZ)."
  }
}

variable "flow_log_retention_days" {
  description = "CloudWatch Logs retention for VPC flow logs, in days."
  type        = number
  default     = 1
}

variable "alb_ingress_cidr" {
  description = "CIDR allowed to reach alb-sg on 80/443. Dev-only IP restriction - widen to 0.0.0.0/0 when actually going live."
  type        = string
  default     = "109.245.225.55/32"
}

variable "alb_to_node_ports" {
  description = "Ports the alb's ip-mode target groups reach on node-sg."
  type        = list(number)
  default     = [8080, 8081]
}
