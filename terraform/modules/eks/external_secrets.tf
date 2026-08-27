# external secrets operator iam: pod identity instead of irsa, oidc federation is scp-blocked in this account
data "aws_iam_policy_document" "external_secrets_pod_identity_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  name               = "${var.name_prefix}-external-secrets-pod-identity-role"
  assume_role_policy = data.aws_iam_policy_document.external_secrets_pod_identity_assume.json
}

# derives the dev/realworld/* wildcard from the actual app secret arn instead of hardcoding
# account id/region here - covers the whole namespace, not just this one secret, matching
# the "path prefix is load-bearing" comment on the secret resource in dev/data
locals {
  app_secrets_arn_pattern = "${regex("^(.*/)[^/]+$", var.app_secret_arn)[0]}*"
}

# scoped to exactly the two secrets eso needs to read - never widen this to secretsmanager:*
# or Resource: "*". the rds managed-credential secret uses aws's own default key (verified via
# describe-secret, KmsKeyId was null), so only the app-secrets cmk needs an explicit kms grant.
data "aws_iam_policy_document" "external_secrets" {
  statement {
    sid     = "ReadRealworldAppSecrets"
    actions = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [
      local.app_secrets_arn_pattern,
      var.rds_master_secret_arn,
    ]
  }

  statement {
    sid       = "DecryptAppSecretsKey"
    actions   = ["kms:Decrypt"]
    resources = [var.app_secrets_kms_key_arn]
  }
}

resource "aws_iam_policy" "external_secrets" {
  name   = "${var.name_prefix}-external-secrets-policy"
  policy = data.aws_iam_policy_document.external_secrets.json
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.external_secrets.arn
}

# "external-secrets" is the chart's default service account name (fullname template off the
# release name external-secrets) - confirmed against the chart's values.yaml, not guessed
resource "aws_eks_pod_identity_association" "external_secrets" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  role_arn        = aws_iam_role.external_secrets.arn

  depends_on = [aws_eks_addon.pod_identity_agent]
}
