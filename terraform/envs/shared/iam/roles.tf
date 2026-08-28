locals {
  gha_user_names = [
    "gha-backend-ecr-push",
    "gha-frontend-ecr-push",
    "gha-infra-plan",
    "gha-infra-apply",
  ]
  gha_user_arns = [for name in local.gha_user_names : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${name}"]

  state_bucket_arn = "arn:aws:s3:::${var.state_bucket_name}"
  lock_table_arn   = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.lock_table_name}"
}

# push-only access to the backend
data "aws_iam_policy_document" "backend_ecr_push" {
  statement {
    sid       = "EcrAuthToken"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPushToBackendRepo"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:BatchGetImage",
      # step 8.5: ci reads the digest of the tag it just pushed, to promote
      # both tag and digest to gitops rather than tag alone
      "ecr:DescribeImages",
    ]
    resources = [module.ecr_backend.repository_arn]
  }
}

module "gha_backend_ecr_push" {
  source = "../../../modules/iam-ci-user"

  user_name = "gha-backend-ecr-push"

  attach_inline_policy = true
  inline_policy_json   = data.aws_iam_policy_document.backend_ecr_push.json
}

# push-only access to the frontend
data "aws_iam_policy_document" "frontend_ecr_push" {
  statement {
    sid       = "EcrAuthToken"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPushToFrontendRepo"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:BatchGetImage",
      # step 8.5: ci reads the digest of the tag it just pushed, to promote
      # both tag and digest to gitops rather than tag alone
      "ecr:DescribeImages",
    ]
    resources = [module.ecr_frontend.repository_arn]
  }
}

module "gha_frontend_ecr_push" {
  source = "../../../modules/iam-ci-user"

  user_name = "gha-frontend-ecr-push"

  attach_inline_policy = true
  inline_policy_json   = data.aws_iam_policy_document.frontend_ecr_push.json
}

# read-only, triggered from PRs against the infra repo
data "aws_iam_policy_document" "infra_plan" {
  statement {
    sid       = "StateBucketRead"
    actions   = ["s3:GetObject"]
    resources = ["${local.state_bucket_arn}/*"]
  }

  statement {
    sid       = "StateBucketList"
    actions   = ["s3:ListBucket"]
    resources = [local.state_bucket_arn]
  }

  statement {
    sid       = "StateLockTable"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
    resources = [local.lock_table_arn]
  }
}

module "gha_infra_plan" {
  source = "../../../modules/iam-ci-user"

  user_name = "gha-infra-plan"

  managed_policy_arns  = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
  attach_inline_policy = true
  inline_policy_json   = data.aws_iam_policy_document.infra_plan.json
}

# write access, triggered only from the "prod" GitHub Environment ---
# PowerUserAccess grants everything except iam/organizations/account (S3 + DynamoDB are already
# covered by it, so no separate state-bucket/lock-table statements are needed here). The gap this
# project actually needs closed is IAM, since Terraform here creates the EKS/RDS service roles -
# so IAM management is granted back, but scoped to the "<workload_role_prefix>-*" naming
# convention and explicitly denied on the gha-* CI users themselves (this composition's own
# output) so this user can never mint itself a new key or widen any sibling CI user's permissions.

data "aws_iam_policy_document" "infra_apply" {
  statement {
    sid = "ManageWorkloadIamRoles"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:GetInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.workload_role_prefix}-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/${var.workload_role_prefix}-*",
    ]
  }

  statement {
    sid = "ManageWorkloadIamPolicies"
    actions = [
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:TagPolicy",
      "iam:UntagPolicy",
    ]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.workload_role_prefix}-*"]
  }

  statement {
    sid       = "PassWorkloadRolesToAwsServices"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.workload_role_prefix}-*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values = [
        "eks.amazonaws.com",
        "rds.amazonaws.com",
        "ec2.amazonaws.com",
        "application-autoscaling.amazonaws.com",
      ]
    }
  }

  # Service-linked roles live at an AWS-controlled path/name, so they can't match the
  # workload_role_prefix pattern above - scoped instead by which service can create one.
  statement {
    sid       = "CreateServiceLinkedRoles"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values = [
        "eks.amazonaws.com",
        "eks-nodegroup.amazonaws.com",
        "rds.amazonaws.com",
        "elasticloadbalancing.amazonaws.com",
      ]
    }
  }

  # Self-protection: this user (and its 3 sibling CI users) can never be modified by gha-infra-apply,
  # closing off the obvious privilege-escalation path of a compromised apply run minting itself a new
  # access key or attaching AdministratorAccess to itself.
  statement {
    sid    = "DenySelfAndSiblingCiUserModification"
    effect = "Deny"
    actions = [
      "iam:AttachUserPolicy",
      "iam:DetachUserPolicy",
      "iam:PutUserPolicy",
      "iam:DeleteUserPolicy",
      "iam:DeleteUser",
      "iam:CreateAccessKey",
      "iam:UpdateAccessKey",
      "iam:DeleteAccessKey",
    ]
    resources = local.gha_user_arns
  }
}

module "gha_infra_apply" {
  source = "../../../modules/iam-ci-user"

  user_name = "gha-infra-apply"

  managed_policy_arns  = ["arn:aws:iam::aws:policy/PowerUserAccess"]
  attach_inline_policy = true
  inline_policy_json   = data.aws_iam_policy_document.infra_apply.json
}
