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

variable "network_state_bucket" {
  description = "S3 bucket holding the network composition's remote state."
  type        = string
  default     = "realworld-terraform-state-262786914511"
}

variable "network_state_key" {
  description = "State key for the network composition, read via terraform_remote_state."
  type        = string
  default     = "dev/network/terraform.tfstate"
}

# longest support window of any current version, has all the addons we need
variable "kubernetes_version" {
  description = "EKS Kubernetes minor version."
  type        = string
  default     = "1.36"
}

variable "eks_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the EKS public API endpoint."
  type        = list(string)
  default     = ["109.245.225.55/32"]
}

variable "eks_cluster_log_retention_days" {
  description = "CloudWatch retention for EKS control-plane logs, in days."
  type        = number
  default     = 7
}

variable "eks_admin_principal_arn" {
  description = "IAM principal ARN granted cluster-admin on the EKS cluster."
  type        = string
  default     = "arn:aws:iam::262786914511:user/tf-user"
}
