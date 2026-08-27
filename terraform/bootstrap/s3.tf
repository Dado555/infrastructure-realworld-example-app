# The Terraform remote state bucket. Split across multiple resource blocks
# (versioning, encryption, public access block, lifecycle) because AWS models
# each of those as an independent sub-resource of the bucket rather than
# inline attributes — this is the standard hashicorp/aws v4+ pattern.
resource "aws_s3_bucket" "terraform_state" {
  bucket = local.state_bucket_name

  # This bucket is the single source of truth for every other composition's
  # state. An accidental `terraform destroy` here would orphan every resource
  # every other stack manages (see the plan's rollback notes for this step).
  # prevent_destroy blocks that at plan time; removing it is a deliberate,
  # reviewed action, not something a routine destroy can do by accident.
  lifecycle {
    prevent_destroy = true
  }
}

# Versioning lets a corrupted or accidentally-overwritten state file be rolled
# back to the previous version instead of being unrecoverable.
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption using the CMK from kms.tf (not the AWS-managed
# aws/s3 key), so every object written to this bucket — including state files
# containing resource attributes and, potentially, sensitive values — is
# encrypted under a key this composition controls and audits.
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.terraform_state.arn
    }

    # Bucket Keys reduce KMS API calls (and therefore KMS request cost) for
    # frequent state writes/reads, at no security cost.
    bucket_key_enabled = true
  }
}

# Belt-and-suspenders against accidental public exposure of state files,
# which routinely contain resource IDs, ARNs, and sometimes secrets. All four
# settings are enabled together, as recommended for any bucket that should
# never be public.
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning (above) keeps every prior state version around indefinitely
# unless something expires them, which would let storage cost grow forever on
# a bucket that is written to on every `terraform apply`. Expiring noncurrent
# versions after 90 days keeps enough history to recover from a bad apply
# while bounding storage growth.
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  # Required whenever a lifecycle rule's transition/expiration actions
  # interact with versioning; without this, `terraform apply` can fail with a
  # "Number of distinct destination storage classes..." style validation
  # error on some provider versions when versioning is enabled.
  depends_on = [aws_s3_bucket_versioning.terraform_state]

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    # An empty filter applies this rule to every object in the bucket. The
    # provider requires either `filter` or `prefix` to be set explicitly (a
    # bare rule with neither is deprecated and now warns at validate time);
    # since this rule isn't scoped to a prefix, an empty filter is the
    # documented way to say "the whole bucket" instead.
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}
