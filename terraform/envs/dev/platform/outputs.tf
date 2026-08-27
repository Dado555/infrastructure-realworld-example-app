output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version running on the control plane."
  value       = module.eks.cluster_version
}

output "cluster_security_group_id" {
  description = "EKS-managed cluster security group ID, for the node group step to consume."
  value       = module.eks.cluster_security_group_id
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL, for a future IRSA provider."
  value       = module.eks.cluster_oidc_issuer_url
}

output "secrets_kms_key_arn" {
  description = "ARN of the dedicated CMK used for EKS secrets envelope encryption."
  value       = module.eks.secrets_kms_key_arn
}

output "node_group_arn" {
  description = "ARN of the managed node group."
  value       = module.eks.node_group_arn
}

output "node_group_status" {
  description = "Status of the managed node group."
  value       = module.eks.node_group_status
}
