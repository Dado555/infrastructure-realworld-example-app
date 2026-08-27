# tag-based, not arn-based - the point is that any future tagged resource (e.g. phase 9's
# prometheus pvc volume) gets covered automatically, no edits to this file needed
resource "aws_backup_selection" "by_tag" {
  name         = "${var.name_prefix}-backup-selection"
  iam_role_arn = aws_iam_role.backup.arn
  plan_id      = aws_backup_plan.this.id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = var.selection_tag_key
    value = var.selection_tag_value
  }
}
