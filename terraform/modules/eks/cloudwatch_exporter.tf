# step 9.6: bridges rds cloudwatch metrics into prometheus's own alerting engine (which can't
# natively query cloudwatch, unlike grafana's separate cloudwatch datasource from step 9.5) -
# pod identity, same as every other in-cluster aws caller here.
#
# GetMetricStatistics (not just GetMetricData) is required - found live via a real
# AccessDeniedException in the exporter's own logs: this specific exporter
# (prometheus/cloudwatch_exporter, the older JVM-based one) calls the legacy
# GetMetricStatistics API internally (io.prometheus.cloudwatch.GetMetricStatisticsDataGetter),
# not GetMetricData like Grafana's own CloudWatch datasource does - the two callers turned out
# to need different actions despite doing the same conceptual job, not identical after all.
data "aws_iam_policy_document" "cloudwatch_exporter_pod_identity_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cloudwatch_exporter" {
  name               = "${var.name_prefix}-cloudwatch-exporter-pod-identity-role"
  assume_role_policy = data.aws_iam_policy_document.cloudwatch_exporter_pod_identity_assume.json
}

# started as a copy of grafana's cloudwatch datasource policy (step 9.5) - both are read-only
# CloudWatch metric consumers, but not identical: this one also needs GetMetricStatistics
# (see the comment above), which Grafana's own datasource never calls.
data "aws_iam_policy_document" "cloudwatch_exporter" {
  statement {
    sid    = "AllowReadingMetricsFromCloudWatch"
    effect = "Allow"
    actions = [
      "cloudwatch:ListMetrics",
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "AllowReadingResourcesForTags"
    effect    = "Allow"
    actions   = ["tag:GetResources"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cloudwatch_exporter" {
  name   = "${var.name_prefix}-cloudwatch-exporter-policy"
  policy = data.aws_iam_policy_document.cloudwatch_exporter.json
}

resource "aws_iam_role_policy_attachment" "cloudwatch_exporter" {
  role       = aws_iam_role.cloudwatch_exporter.name
  policy_arn = aws_iam_policy.cloudwatch_exporter.arn
}

# "cloudwatch-exporter" is set explicitly via serviceAccount.name in charts/observability's
# values.yaml (prometheus-cloudwatch-exporter subchart) - not the chart's auto-generated
# fullname, so this association has a stable, known target instead of needing to check kubectl
# after the fact.
resource "aws_eks_pod_identity_association" "cloudwatch_exporter" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "observability"
  service_account = "cloudwatch-exporter"
  role_arn        = aws_iam_role.cloudwatch_exporter.arn

  depends_on = [aws_eks_addon.pod_identity_agent]
}
