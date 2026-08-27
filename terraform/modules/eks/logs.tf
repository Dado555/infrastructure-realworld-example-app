# Created explicitly (not left to EKS's own auto-create) so retention is dev-short instead of
# the "never expire" default EKS would otherwise apply.
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.name_prefix}-eks/cluster"
  retention_in_days = var.cluster_log_retention_days

  tags = {
    Name = "${var.name_prefix}-eks-cluster-logs"
  }
}
