# versions pinned to each addon's defaultVersion for k8s 1.36 per `aws eks describe-addon-versions` (2026-08-27), not "latest"
locals {
  addon_version_vpc_cni            = "v1.22.4-eksbuild.3"
  addon_version_coredns            = "v1.14.3-eksbuild.14"
  addon_version_kube_proxy         = "v1.36.0-eksbuild.17"
  addon_version_ebs_csi_driver     = "v1.64.0-eksbuild.1"
  addon_version_pod_identity_agent = "v1.3.10-eksbuild.3"
  # step 9.1, pinned 2026-08-29
  addon_version_cloudwatch_observability = "v6.5.0-eksbuild.1"
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "vpc-cni"
  addon_version = local.addon_version_vpc_cni

  # eks bootstraps vpc-cni as self-managed before this resource exists; overwrite instead of failing on conflict
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # nodeagent ships by default but enforcement is off until this flag turns on the NetworkPolicy->PolicyEndpoint reconciler
  #
  # step 9.1: prefix delegation raises the per-node pod ceiling well past the
  # default ENI-secondary-IP limit (17 pods/node on t3.medium, confirmed live -
  # hit it twice now, step 6.3 and again installing the cloudwatch-observability
  # addon's daemonsets). free (no new aws resources), unlike adding a node.
  # NOTE: existing already-allocated secondary ips on already-attached enis
  # don't retroactively convert to prefixes - if today's specific stuck pod
  # doesn't clear once this rolls out, that's why, and the real fix at that
  # point is cycling the nodes (or as a interim step, adding a 3rd node).
  configuration_values = jsonencode({
    enableNetworkPolicy = "true"
    env = {
      ENABLE_PREFIX_DELEGATION = "true"
    }
  })

  tags = {
    Name = "${var.name_prefix}-vpc-cni"
  }
}

resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "coredns"
  addon_version = local.addon_version_coredns

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # coredns pods need a schedulable node to reach Active
  depends_on = [aws_eks_node_group.this]

  tags = {
    Name = "${var.name_prefix}-coredns"
  }
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "kube-proxy"
  addon_version = local.addon_version_kube_proxy

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Name = "${var.name_prefix}-kube-proxy"
  }
}

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "eks-pod-identity-agent"
  addon_version = local.addon_version_pod_identity_agent

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Name = "${var.name_prefix}-pod-identity-agent"
  }
}

# --- ebs csi driver: pod identity instead of irsa, oidc federation is scp-blocked in this account ---

data "aws_iam_policy_document" "ebs_csi_pod_identity_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.name_prefix}-ebs-csi-pod-identity-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_pod_identity_assume.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# "ebs-csi-controller-sa" is the fixed service account name baked into the ebs-csi-driver addon/helm chart
resource "aws_eks_pod_identity_association" "ebs_csi" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi.arn

  depends_on = [aws_eks_addon.pod_identity_agent]
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "aws-ebs-csi-driver"
  addon_version = local.addon_version_ebs_csi_driver

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # credentials must exist before the controller pods start, or they crashloop
  depends_on = [aws_eks_pod_identity_association.ebs_csi, aws_eks_node_group.this]

  tags = {
    Name = "${var.name_prefix}-ebs-csi-driver"
  }
}
