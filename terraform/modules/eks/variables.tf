variable "name_prefix" {
  description = "Prefix applied to resource names, e.g. realworld-aws-dev."
  type        = string
}

variable "kubernetes_version" {
  description = "EKS Kubernetes minor version, e.g. 1.36."
  type        = string
}

variable "subnet_ids" {
  description = "Private-app subnets for the cluster."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "EKS requires subnets in at least 2 AZs."
  }
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint. Never leave at 0.0.0.0/0."
  type        = list(string)

  validation {
    condition     = !contains(var.endpoint_public_access_cidrs, "0.0.0.0/0")
    error_message = "0.0.0.0/0 is not allowed - restrict the public endpoint to known CIDRs."
  }
}

variable "cluster_log_retention_days" {
  description = "CloudWatch retention for the control-plane log group, in days. Short in dev to keep cost down."
  type        = number
  default     = 7
}

variable "admin_principal_arn" {
  description = "IAM principal ARN granted cluster-admin via an EKS access entry (not aws-auth)."
  type        = string
}
