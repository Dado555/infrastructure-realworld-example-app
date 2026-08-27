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

# Picked 2026-08-27 via `aws eks describe-cluster-versions`: 1.36 is AWS's current defaultVersion,
# has the longest remaining standard/extended support window of anything on offer (std support to
# 2027-08, ext to 2028-08 - a full 5 months longer than 1.35 and 8 months longer than 1.34, which
# exits standard support in ~3 months), and every addon this project needs (vpc-cni, coredns,
# kube-proxy, ebs-csi-driver, pod-identity-agent) already has a stable default build for it. Newest
# here isn't a blind pick - it's newest, longest-lived, and already fully covered by the addon
# ecosystem at once.
variable "kubernetes_version" {
  description = "EKS Kubernetes minor version."
  type        = string
  default     = "1.36"
}

# Same IP used for the ALB security group in Step 4.3 - may need updating if it has changed since.
variable "eks_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the EKS public API endpoint."
  type        = list(string)
  default     = ["109.245.225.55/32"]
}

variable "eks_cluster_log_retention_days" {
  description = "CloudWatch retention for EKS control-plane logs, in days. Short in dev to keep cost down."
  type        = number
  default     = 7
}

# tf-user is the identity running kubectl for verification - granted cluster-admin via an access entry.
variable "eks_admin_principal_arn" {
  description = "IAM principal ARN granted cluster-admin on the EKS cluster."
  type        = string
  default     = "arn:aws:iam::262786914511:user/tf-user"
}
