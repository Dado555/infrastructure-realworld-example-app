variable "user_name" {
  description = "Name of the IAM user."
  type        = string
}

variable "managed_policy_arns" {
  description = "AWS-managed policy ARNs to attach to the user."
  type        = list(string)
  default     = []
}

variable "inline_policy_json" {
  description = "Inline permissions policy (JSON) to attach to the user, when attach_inline_policy is true."
  type        = string
  default     = null
}

variable "attach_inline_policy" {
  description = "Whether to attach inline_policy_json. Kept separate from the JSON value itself (usually a data.aws_iam_policy_document.json reference not known until apply) so `count` has something static to evaluate at plan time."
  type        = bool
  default     = false
}
