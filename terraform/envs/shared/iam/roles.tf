locals {
  # Static ARN construction (account id + fixed name) avoids a role referencing its own
  # aws_iam_role resource, which would be a dependency cycle.
  gha_role_names = [
    "gha-backend-ecr-push",
    "gha-frontend-ecr-push",
    "gha-infra-plan",
    "gha-infra-apply",
  ]
  gha_role_arns = [for name in local.gha_role_names : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${name}"]

  state_bucket_arn = "arn:aws:s3:::${var.state_bucket_name}"
  lock_table_arn   = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.lock_table_name}"
}

# --- gha-backend-ecr-push: push-only access to the backend ECR repo, triggered from master ---

data "aws_iam_policy_document" "backend_ecr_push" {
  statement {
    sid       = "EcrAuthToken"
    actions   = ["ecr:GetAuthorizationToken"] # account-wide by AWS design, cannot be resource-scoped
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
    ]
    resources = [module.ecr_backend.repository_arn]
  }
}

module "gha_backend_ecr_push" {
  source = "../../../modules/github-oidc-role"

  role_name         = "gha-backend-ecr-push"
  oidc_provider_arn = aws_iam_openid_connect_provider.github.arn
  sub_claims        = ["repo:${var.github_owner}/${var.backend_repo}:ref:refs/heads/master"]

  attach_inline_policy = true
  inline_policy_json   = data.aws_iam_policy_document.backend_ecr_push.json
}

# --- gha-frontend-ecr-push: push-only access to the frontend ECR repo, triggered from main ---

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
    ]
    resources = [module.ecr_frontend.repository_arn]
  }
}

module "gha_frontend_ecr_push" {
  source = "../../../modules/github-oidc-role"

  role_name         = "gha-frontend-ecr-push"
  oidc_provider_arn = aws_iam_openid_connect_provider.github.arn
  sub_claims        = ["repo:${var.github_owner}/${var.frontend_repo}:ref:refs/heads/main"]

  attach_inline_policy = true
  inline_policy_json   = data.aws_iam_policy_document.frontend_ecr_push.json
}

# --- gha-infra-plan: read-only, triggered from PRs against the infra repo ---
# ReadOnlyAccess already covers S3/DynamoDB reads broadly, but the state-bucket and lock-table
# statements are kept explicit so this policy is self-documenting about what plan actually needs -
# and DynamoDB write is required regardless, since the S3 backend still takes a lock to run `plan`.

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
  source = "../../../modules/github-oidc-role"

  role_name         = "gha-infra-plan"
  oidc_provider_arn = aws_iam_openid_connect_provider.github.arn
  sub_claims        = ["repo:${var.github_owner}/${var.infra_repo}:pull_request"]

  managed_policy_arns  = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
  attach_inline_policy = true
  inline_policy_json   = data.aws_iam_policy_document.infra_plan.json
}

# --- gha-infra-apply: write access, triggered only from the "prod" GitHub Environment ---
# PowerUserAccess grants everything except iam/organizations/account (S3 + DynamoDB are already
# covered by it, so no separate state-bucket/lock-table statements are needed here). The gap this
# project actually needs closed is IAM, since Terraform here creates the EKS/RDS service roles -
# so IAM management is granted back, but scoped to the "<workload_role_prefix>-*" naming
# convention and explicitly denied on the gha-* CI roles themselves (this composition's own
# output) so this role can never widen its own trust policy or any sibling CI role's permissions.

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

  # Read-only on the one OIDC provider this composition owns - create/delete stays a bootstrap-profile
  # action, not something the automated apply role can do to its own trust anchor.
  statement {
    sid       = "ReadOidcProvider"
    actions   = ["iam:GetOpenIDConnectProvider", "iam:ListOpenIDConnectProviders"]
    resources = [aws_iam_openid_connect_provider.github.arn]
  }

  # Self-protection: this role (and its 3 sibling CI roles) can never be modified by gha-infra-apply,
  # closing off the obvious privilege-escalation path of a compromised apply run widening its own
  # trust policy or attaching AdministratorAccess to itself.
  statement {
    sid    = "DenySelfAndSiblingCiRoleModification"
    effect = "Deny"
    actions = [
      "iam:UpdateAssumeRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:DeleteRole",
    ]
    resources = local.gha_role_arns
  }
}

module "gha_infra_apply" {
  source = "../../../modules/github-oidc-role"

  role_name         = "gha-infra-apply"
  oidc_provider_arn = aws_iam_openid_connect_provider.github.arn
  sub_claims        = ["repo:${var.github_owner}/${var.infra_repo}:environment:prod"]

  managed_policy_arns  = ["arn:aws:iam::aws:policy/PowerUserAccess"]
  attach_inline_policy = true
  inline_policy_json   = data.aws_iam_policy_document.infra_apply.json
}
