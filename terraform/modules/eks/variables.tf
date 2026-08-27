variable "name_prefix" {
  description = "Prefix applied to resource names, e.g. realworld-aws-dev."
  type        = string
}

variable "kubernetes_version" {
  description = "EKS Kubernetes minor version, e.g. 1.36."
  type        = string
}

variable "subnet_ids" {
  description = "Private-app subnets for the cluster control plane ENIs and the node group."
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

variable "node_security_group_id" {
  description = "Phase-4 node-sg ID, for ALB-to-pod traffic once workloads are deployed."
  type        = string
}

variable "node_instance_type" {
  description = "EC2 instance type for the managed node group."
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Desired node count."
  type        = number
  default     = 1
}

variable "node_min_size" {
  description = "Minimum node count."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum node count."
  type        = number
  default     = 1
}

variable "node_capacity_type" {
  description = "ON_DEMAND or SPOT. Stay on-demand until the platform is stable."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "node_ami_type" {
  description = "EKS AMI type for the node group. AL2 isn't published for k8s 1.33+, so AL2023 is the default."
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}
