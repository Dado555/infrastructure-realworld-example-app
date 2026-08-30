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

# step 9.3: grafana admin credentials, eso-synced - never in a helm values file. separate
# secretsmanager path (dev/observability/*, not dev/realworld/*) mirrors the prod/realworld/*
# split from step 8.6 - observability is a different logical category from app secrets, not
# just a convenience reuse of the existing wildcard.
resource "random_password" "grafana_admin" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "grafana" {
  name                    = "${var.environment}/observability/grafana"
  description             = "Grafana admin credentials for ${var.environment}"
  kms_key_id              = aws_kms_key.app_secrets.arn
  recovery_window_in_days = 7
}

# key names (admin-user/admin-password) match kube-prometheus-stack's grafana subchart
# defaults (admin.userKey/admin.passwordKey) exactly, so the ExternalSecret can a plain
# dataFrom.extract with no per-key template block
resource "aws_secretsmanager_secret_version" "grafana" {
  secret_id = aws_secretsmanager_secret.grafana.id
  secret_string = jsonencode({
    admin-user     = "admin"
    admin-password = random_password.grafana_admin.result
  })
}

# step 9.6: alertmanager's slack webhook - same dev/observability/* path prefix as grafana's
# secret above (same logical category: observability-tooling credentials, not app secrets).
resource "aws_secretsmanager_secret" "alertmanager_slack" {
  name                    = "${var.environment}/observability/alertmanager-slack"
  description             = "Slack incoming webhook URL for Alertmanager notifications, for ${var.environment}"
  kms_key_id              = aws_kms_key.app_secrets.arn
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "alertmanager_slack" {
  secret_id = aws_secretsmanager_secret.alertmanager_slack.id
  secret_string = jsonencode({
    slack-webhook-url = var.slack_webhook_url
  })
}
