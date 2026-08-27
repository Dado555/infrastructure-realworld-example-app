# Control plane only - no node group here (that's the next step). vpc_config.security_group_ids is
# left unset so EKS creates and manages its own cluster security group for control-plane<->node
# traffic, kept separate from Phase 4's hand-authored node-sg (which models ALB->node app-port
# traffic, not control-plane API traffic). The node group step attaches node-sg to the nodes and can
# reference cluster_security_group_id (output below) alongside it.
resource "aws_eks_cluster" "this" {
  name     = "${var.name_prefix}-eks"
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.endpoint_public_access_cidrs
  }

  # Secrets envelope encryption - the setting that can't be bolted on after creation.
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks_secrets.arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # API-only auth - access entries are the only way in, no legacy aws-auth ConfigMap.
  access_config {
    authentication_mode = "API"
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_cloudwatch_log_group.cluster,
  ]

  tags = {
    Name = "${var.name_prefix}-eks"
  }
}
