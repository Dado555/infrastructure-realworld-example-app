# Checked via `aws iam list-open-id-connect-providers` before writing this - account has none for
# token.actions.githubusercontent.com yet, so this creates the provider rather than referencing one.
# thumbprint_list is a required field on the resource but AWS no longer actually validates it against
# the live cert for GitHub's well-known OIDC endpoint - these two values were still pulled live via
# `openssl s_client` against token.actions.githubusercontent.com rather than copied from memory, since
# GitHub's CA has rotated before (they're on Let's Encrypt now, not the DigiCert chain older guides cite):
# top-of-chain (ISRG Root R2) and the intermediate below it (Let's Encrypt R2), as a rotation buffer.
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [
    "ab9d0263244dd0326eb67015705a667e79cfe998",
    "2d74d6dfd96eea55ad7baafa0d3c6552b2dadc37",
  ]
}
