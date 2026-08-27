variable "role_name" {
  description = "Name of the IAM role."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the aws_iam_openid_connect_provider for token.actions.githubusercontent.com."
  type        = string
}

variable "audience" {
  description = "Expected OIDC audience claim."
  type        = string
  default     = "sts.amazonaws.com"
}

variable "sub_claims" {
  description = "Exact GitHub OIDC 'sub' claim values allowed to assume this role. Must be fully-specified (repo + ref/pull_request/environment) - wildcards defeat the point of scoping the trust policy."
  type        = list(string)

  validation {
    condition     = alltrue([for s in var.sub_claims : !can(regex("\\*", s))])
    error_message = "sub_claims must be exact values, not wildcard patterns."
  }

  validation {
    condition     = length(var.sub_claims) > 0
    error_message = "At least one sub claim is required."
  }
}

variable "managed_policy_arns" {
  description = "AWS-managed policy ARNs to attach to the role."
  type        = list(string)
  default     = []
}

variable "inline_policy_json" {
  description = "Inline permissions policy (JSON) to attach to the role, when attach_inline_policy is true."
  type        = string
  default     = null
}

variable "attach_inline_policy" {
  description = "Whether to attach inline_policy_json. Kept separate from the JSON value itself (usually a data.aws_iam_policy_document.json reference not known until apply) so `count` has something static to evaluate at plan time."
  type        = bool
  default     = false
}
