variable "aws_region" {
  description = "AWS region the bootstrap resources are created in."
  type        = string
}

variable "project" {
  description = "Identifier for the project. Applied as the Project tag on every resource for cost attribution and search."
  type        = string
  default     = "realworld-aws"
}

variable "environment" {
  description = "Logical environment these resources belong to, applied as the Environment tag."
  type        = string
  default     = "global"
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
