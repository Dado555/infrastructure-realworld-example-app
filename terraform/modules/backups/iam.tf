# standard trust policy for the aws backup service to assume this role during backup jobs
data "aws_iam_policy_document" "backup_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup" {
  name               = "${var.name_prefix}-backup-role"
  assume_role_policy = data.aws_iam_policy_document.backup_assume.json
}

# aws-managed policy for the backup service itself (list/describe/tag resources, start
# backup jobs). arn confirmed via `aws iam get-policy` - lives under the service-role/ path,
# not the plain policy/ path. restores policy is intentionally not attached here - that's
# scoped to the separate restore-verification dispatch (step 6.4's follow-up)
resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}
