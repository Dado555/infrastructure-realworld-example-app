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
  default     = "prod"
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
