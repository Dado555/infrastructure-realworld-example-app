# 64 alphanumeric chars, no specials - same as dev/data's jwt secret, plenty of
# entropy for an hs256 hmac key, no escaping surprises through k8s secret -> env var
resource "random_password" "jwt_secret" {
  length  = 64
  special = false
}

# path prefix prod/realworld/* is load-bearing - the eks module's eso iam policy
# scopes access by it, same pattern as dev/realworld/*
resource "aws_secretsmanager_secret" "app" {
  name                    = "${var.environment}/realworld/app"
  description             = "RealWorld app secrets (JWT signing key) for ${var.environment}"
  recovery_window_in_days = 7

  # no dedicated cmk (unlike dev's app_secrets key) - uses secretsmanager's
  # default aws-managed key. adr 0015: this environment is otherwise entirely
  # reusing dev's infrastructure, so a new kms key (plus the eso iam grant it
  # would need) isn't worth it for one secret.
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id
  secret_string = jsonencode({
    JWT_SECRET = random_password.jwt_secret.result
  })
}
