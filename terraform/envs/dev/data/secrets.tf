# dedicated cmk for app secrets - same per-service key pattern as rds/eks/ecr, not shared
resource "aws_kms_key" "app_secrets" {
  description             = "Encrypts application secrets for ${var.project}-${var.environment}"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "app_secrets" {
  name          = "alias/${var.project}-${var.environment}-app-secrets"
  target_key_id = aws_kms_key.app_secrets.key_id
}

# 64 alphanumeric chars, no specials - plenty of entropy for an hs256 hmac key, and
# avoids any escaping surprises later when this flows through k8s secret -> env var
resource "random_password" "jwt_secret" {
  length  = 64
  special = false
}

# path prefix dev/realworld/* is load-bearing - step 6.3's iam policy scopes access by it
resource "aws_secretsmanager_secret" "app" {
  name                    = "${var.environment}/realworld/app"
  description             = "RealWorld app secrets (JWT signing key) for ${var.environment}"
  kms_key_id              = aws_kms_key.app_secrets.arn
  recovery_window_in_days = 7 # short window in dev so re-apply cycles aren't blocked by "scheduled for deletion"
}

# random_password.result is marked sensitive by the provider schema already - no extra
# suppression needed, plan output redacts it same as any other sensitive attribute
resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id
  secret_string = jsonencode({
    JWT_SECRET = random_password.jwt_secret.result
  })
}

# rotation for the rds master credential is deferred - aws's manage_master_user_password
# feature (already on from step 6.1) supports enabling built-in rotation later without a
# custom lambda; that's the likely path, not a hand-rolled rotation function
