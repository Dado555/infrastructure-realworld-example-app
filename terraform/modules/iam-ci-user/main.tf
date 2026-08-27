# CI identity as an IAM user + long-lived key, since OIDC federation is blocked in this account
resource "aws_iam_user" "this" {
  name = var.user_name
}

resource "aws_iam_user_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)

  user       = aws_iam_user.this.name
  policy_arn = each.value
}

resource "aws_iam_user_policy" "inline" {
  count = var.attach_inline_policy ? 1 : 0

  name   = "${var.user_name}-permissions"
  user   = aws_iam_user.this.name
  policy = var.inline_policy_json
}

resource "aws_iam_access_key" "this" {
  user = aws_iam_user.this.name
}
