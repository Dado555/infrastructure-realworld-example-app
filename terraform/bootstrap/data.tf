# Data sources shared by the bootstrap resources. Currently just the calling
# account's identity, used to build a globally-unique S3 bucket name (see
# locals.tf) without hardcoding the account ID as a literal in source.
data "aws_caller_identity" "current" {}
