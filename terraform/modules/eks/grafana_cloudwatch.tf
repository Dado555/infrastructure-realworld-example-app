# step 9.5: grafana's cloudwatch datasource (rds metrics for the database dashboard) - pod
# identity instead of irsa, oidc federation is scp-blocked in this account, same as every
# other in-cluster aws caller here.
data "aws_iam_policy_document" "grafana_cloudwatch_pod_identity_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "grafana_cloudwatch" {
  name               = "${var.name_prefix}-grafana-cloudwatch-pod-identity-role"
  assume_role_policy = data.aws_iam_policy_document.grafana_cloudwatch_pod_identity_assume.json
}

# grafana's own documented minimal policy for the cloudwatch datasource (metrics-only - this
# project ships no cloudwatch logs query use case, that's covered by step 9.1's dedicated
# pipeline instead). every action here is describe/list/get - none support resource-level arn
# scoping in AWS's own IAM action reference, so Resource "*" is what AWS requires, not a
# deliberately broad grant. pi:GetResourceMetrics (Performance Insights) dropped - not enabled
# on this project's RDS instance.
data "aws_iam_policy_document" "grafana_cloudwatch" {
  statement {
    sid    = "AllowReadingMetricsFromCloudWatch"
    effect = "Allow"
    actions = [
      "cloudwatch:DescribeAlarmsForMetric",
      "cloudwatch:DescribeAlarmHistory",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:ListMetrics",
      "cloudwatch:GetMetricData",
      "cloudwatch:GetInsightRuleReport",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "AllowReadingTagsInstancesRegionsFromEC2"
    effect    = "Allow"
    actions   = ["ec2:DescribeTags", "ec2:DescribeInstances", "ec2:DescribeRegions"]
    resources = ["*"]
  }

  statement {
    sid       = "AllowReadingResourcesForTags"
    effect    = "Allow"
    actions   = ["tag:GetResources"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "grafana_cloudwatch" {
  name   = "${var.name_prefix}-grafana-cloudwatch-policy"
  policy = data.aws_iam_policy_document.grafana_cloudwatch.json
}

resource "aws_iam_role_policy_attachment" "grafana_cloudwatch" {
  role       = aws_iam_role.grafana_cloudwatch.name
  policy_arn = aws_iam_policy.grafana_cloudwatch.arn
}

# "observability-grafana" matches the kube-prometheus-stack release name (observability) plus
# the grafana subchart's own fullname template - confirmed live via
# `kubectl get statefulset observability-grafana -o jsonpath='{.spec.template.spec.serviceAccountName}'`
resource "aws_eks_pod_identity_association" "grafana_cloudwatch" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "observability"
  service_account = "observability-grafana"
  role_arn        = aws_iam_role.grafana_cloudwatch.arn

  depends_on = [aws_eks_addon.pod_identity_agent]
}
