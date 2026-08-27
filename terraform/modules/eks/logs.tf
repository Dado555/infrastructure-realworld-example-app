# created explicitly so retention is short, not "never expire"
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.name_prefix}-eks/cluster"
  retention_in_days = var.cluster_log_retention_days

  tags = {
    Name = "${var.name_prefix}-eks-cluster-logs"
  }
}
