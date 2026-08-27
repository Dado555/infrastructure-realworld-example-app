# --- aws load balancer controller iam: pod identity instead of irsa, oidc federation is scp-blocked in this account ---
# helm install + test ingress happen in a later step; this only prepares the role so the chart has something to bind to

data "aws_iam_policy_document" "lb_controller_pod_identity_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lb_controller" {
  name               = "${var.name_prefix}-lb-controller-pod-identity-role"
  assume_role_policy = data.aws_iam_policy_document.lb_controller_pod_identity_assume.json
}

# official policy from kubernetes-sigs/aws-load-balancer-controller v3.5.0 docs/install/iam_policy.json, fetched verbatim (not hand-transcribed)
resource "aws_iam_policy" "lb_controller" {
  name   = "${var.name_prefix}-lb-controller-policy"
  policy = file("${path.module}/lb_controller_iam_policy.json")
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}

# "aws-load-balancer-controller" is the fixed service account name baked into the controller's helm chart
resource "aws_eks_pod_identity_association" "lb_controller" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.lb_controller.arn

  depends_on = [aws_eks_addon.pod_identity_agent]
}
