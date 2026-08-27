# Dedicated CMK for EKS secrets envelope encryption - not the ECR or bootstrap keys, per this
# project's per-service blast-radius pattern. Must be set at cluster creation; cannot be added later.
resource "aws_kms_key" "eks_secrets" {
  description         = "Envelope-encrypts Kubernetes secrets for ${var.name_prefix}-eks"
  enable_key_rotation = true

  # Notice and cancel an accidental deletion before the key becomes unrecoverable
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/${var.name_prefix}-eks-secrets"
  target_key_id = aws_kms_key.eks_secrets.key_id
}
