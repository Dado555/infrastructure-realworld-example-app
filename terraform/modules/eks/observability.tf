# step 9.1: container logs + classic container insights metrics, via the
# amazon-cloudwatch-observability addon. pod identity, not irsa - oidc
# federation is scp-blocked in this account (adr 0009).
#
# deliberately OFF, none of these were asked for and each is a real,
# separate cost surface:
# - otelContainerInsights: the newer, pricier, per-container-granularity
#   "enhanced" container insights tier - exactly what the plan calls out
#   ("no enhanced container insights unless asked").
# - applicationSignals: apm/distributed tracing (x-ray based).
# - kubeStateMetrics / nodeExporter: prometheus-style exporters - a future
#   kube-prometheus-stack step would bring its own, running this addon's
#   copies too would just be redundant duplicate scraping.
# - dcgmExporter / neuronMonitor: gpu / inferentia-trainium metrics - no
#   matching hardware in this cluster (t3.medium nodes only).

locals {
  # created explicitly with retention set BEFORE the addon exists, so fluent-bit/
  # the cloudwatch agent write into already-correctly-configured log groups
  # instead of auto-creating their own never-expire defaults (the "cost trap"
  # the plan calls out by name)
  container_insights_log_groups = ["application", "dataplane", "host", "performance"]
}

data "aws_caller_identity" "current" {}

# cloudwatch logs needs an explicit grant in the key's own policy for its
# service principal - unlike rds/ecr/app-secrets, it doesn't just work off the
# caller's iam permissions, since logs calls kms on the log group's behalf.
# found live: CreateLogGroup failed with AccessDeniedException ("specified kms
# key does not exist or is not allowed") until this was added - the default
# key policy (account-root-only) isn't enough. scoped to just this account's
# log groups via the encryption-context condition, not a blanket grant.
data "aws_iam_policy_document" "cloudwatch_observability_key" {
  statement {
    sid       = "AllowAccountRootFullAccess"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid = "AllowCloudWatchLogsToUseKey"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["logs.${var.aws_region}.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:*"]
    }
  }
}

resource "aws_kms_key" "cloudwatch_observability" {
  description             = "Encrypts CloudWatch Observability (Container Insights) log groups for ${var.name_prefix}"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.cloudwatch_observability_key.json
}

resource "aws_kms_alias" "cloudwatch_observability" {
  name          = "alias/${var.name_prefix}-cloudwatch-observability"
  target_key_id = aws_kms_key.cloudwatch_observability.key_id
}

resource "aws_cloudwatch_log_group" "container_insights" {
  for_each = toset(local.container_insights_log_groups)

  name              = "/aws/containerinsights/${aws_eks_cluster.this.name}/${each.key}"
  retention_in_days = var.observability_log_retention_days
  kms_key_id        = aws_kms_key.cloudwatch_observability.arn

  tags = {
    Name = "${var.name_prefix}-containerinsights-${each.key}"
  }
}

data "aws_iam_policy_document" "cloudwatch_observability_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cloudwatch_observability" {
  name               = "${var.name_prefix}-cloudwatch-observability-pod-identity-role"
  assume_role_policy = data.aws_iam_policy_document.cloudwatch_observability_assume.json
}

resource "aws_iam_role_policy_attachment" "cloudwatch_observability" {
  role       = aws_iam_role.cloudwatch_observability.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# "cloudwatch-agent" in the "amazon-cloudwatch" namespace is the addon's fixed
# service account name - verify live after install (kubectl get sa -n
# amazon-cloudwatch), don't just trust this comment
resource "aws_eks_pod_identity_association" "cloudwatch_observability" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "amazon-cloudwatch"
  service_account = "cloudwatch-agent"
  role_arn        = aws_iam_role.cloudwatch_observability.arn

  depends_on = [aws_eks_addon.pod_identity_agent]
}

resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "amazon-cloudwatch-observability"
  addon_version = local.addon_version_cloudwatch_observability

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  configuration_values = jsonencode({
    containerLogs = {
      enabled = true
    }
    containerInsights = {
      enabled = true
    }
    otelContainerInsights = {
      enabled = false
    }
    applicationSignals = {
      enabled = false
    }
    kubeStateMetrics = {
      enabled = false
    }
    nodeExporter = {
      enabled = false
    }
    dcgmExporter = {
      enabled = false
    }
    neuronMonitor = {
      enabled = false
    }
  })

  # credentials must exist before the agent pods start, or they crashloop -
  # same reasoning as the ebs-csi-driver addon above. log groups created first
  # too, so nothing ever falls back to auto-created never-expire defaults.
  depends_on = [
    aws_eks_pod_identity_association.cloudwatch_observability,
    aws_cloudwatch_log_group.container_insights,
    aws_eks_node_group.this,
  ]

  tags = {
    Name = "${var.name_prefix}-cloudwatch-observability"
  }
}
