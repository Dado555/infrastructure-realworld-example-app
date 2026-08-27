# dedicated key for kubernetes secrets
resource "aws_kms_key" "eks_secrets" {
  description             = "Envelope-encrypts Kubernetes secrets for ${var.name_prefix}-eks"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/${var.name_prefix}-eks-secrets"
  target_key_id = aws_kms_key.eks_secrets.key_id
}
