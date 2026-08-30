variable "name_prefix" {
  description = "Prefix applied to resource names, e.g. realworld-aws-dev."
  type        = string
}

# step 9.1: needed to scope the cloudwatch-observability kms key policy to
# this region's log group arns
variable "aws_region" {
  description = "AWS region this module's resources are created in."
  type        = string
  default     = "us-east-1"
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

# adr 0015: one eks cluster serves both dev and prod, so there's one shared set
# of container-insights log groups, not a per-environment split - same "one
# cluster, one retention" situation cluster_log_retention_days above already has
variable "observability_log_retention_days" {
  description = "CloudWatch retention for the amazon-cloudwatch-observability addon's container-insights log groups, in days."
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
  default     = 2
}

variable "node_min_size" {
  description = "Minimum node count."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum node count."
  type        = number
  default     = 2
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

# step 9.3: the un-overridden default (17, the standard ENI-based formula for t3.medium) is a
# hard per-node pod ceiling unrelated to actual cpu/memory capacity - first hit in step 6.3, hit
# again in step 9.1 (cloudwatch observability daemonsets), and now blocks kube-prometheus-stack's
# node-exporter daemonset outright since 2 of 3 nodes are already at 17/17. prefix delegation
# (step 9.1) fixed ip *allocation* efficiency but never raised this ceiling - it's a separate,
# statically-computed kubelet value baked in at node bootstrap. 110 matches upstream kubernetes'
# own general-purpose recommended ceiling, well above what this node size could ever host on
# cpu/memory alone, so it removes pod-count as an artificial constraint without being unbounded.
variable "node_max_pods" {
  description = "Overrides kubelet's --max-pods via nodeadm NodeConfig user-data, replacing the default ENI-based per-instance-type calculation."
  type        = number
  default     = 110
}

# step 6.3: external secrets operator inputs, sourced from dev/data's remote state
variable "app_secret_arn" {
  description = "ARN of the dev/realworld/app secret (JWT signing key). Used to derive the dev/realworld/* resource pattern for eso's iam policy."
  type        = string
}

variable "app_secrets_kms_key_arn" {
  description = "ARN of the CMK encrypting the app secrets, granted to eso for kms:Decrypt."
  type        = string
}

variable "rds_master_secret_arn" {
  description = "ARN of the RDS-managed master credential secret (rds!db-... naming, doesn't match the dev/realworld/* prefix). Granted explicitly, not via wildcard."
  type        = string
}

# adr 0015: prod reuses this same eks cluster/eso installation rather than
# getting its own, so eso's iam policy needs prod/realworld/* too
variable "additional_app_secret_arn" {
  description = "ARN of another environment's app secret (e.g. prod/realworld/app), to derive a second wildcard resource pattern for eso's iam policy. Null if there isn't one."
  type        = string
  default     = null
}

# step 9.3: separate dev/observability/* pattern, not folded into dev/realworld/* - observability
# secrets (grafana admin creds) are a different logical category from app secrets, matching the
# same reasoning that already split prod/realworld/* out as its own pattern in step 8.6.
variable "observability_secret_arn" {
  description = "ARN of the dev/observability/grafana secret, to derive the dev/observability/* resource pattern for eso's iam policy."
  type        = string
}
