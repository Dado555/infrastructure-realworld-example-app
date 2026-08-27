output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster."
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "API server endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 PEM cluster CA, needed for kubeconfig."
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "cluster_version" {
  description = "Kubernetes version running on the control plane."
  value       = aws_eks_cluster.this.version
}

output "cluster_security_group_id" {
  description = "EKS-managed cluster security group ID, for the node group step to attach alongside node-sg."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL, for a future IRSA provider (not created in this step)."
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "cluster_iam_role_arn" {
  description = "ARN of the dedicated EKS cluster service role."
  value       = aws_iam_role.cluster.arn
}

output "secrets_kms_key_arn" {
  description = "ARN of the dedicated CMK used for EKS secrets envelope encryption."
  value       = aws_kms_key.eks_secrets.arn
}

output "secrets_kms_key_id" {
  description = "ID of the dedicated CMK used for EKS secrets envelope encryption."
  value       = aws_kms_key.eks_secrets.key_id
}

output "cluster_log_group_name" {
  description = "CloudWatch log group name for control-plane logs."
  value       = aws_cloudwatch_log_group.cluster.name
}

output "node_group_arn" {
  description = "ARN of the managed node group."
  value       = aws_eks_node_group.this.arn
}

output "node_group_status" {
  description = "Status of the managed node group."
  value       = aws_eks_node_group.this.status
}

output "node_iam_role_arn" {
  description = "ARN of the node IAM role."
  value       = aws_iam_role.node.arn
}

output "lb_controller_role_arn" {
  description = "ARN of the LB controller's IAM role, for the helm chart's service-account annotation."
  value       = aws_iam_role.lb_controller.arn
}

output "external_secrets_role_arn" {
  description = "ARN of the ESO pod identity role, scoped to the dev/realworld/* secrets and the rds managed credential."
  value       = aws_iam_role.external_secrets.arn
}
