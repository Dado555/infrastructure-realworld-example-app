variable "repository_name" {
  description = "Name of the ECR repository."
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt images at rest."
  type        = string
}

variable "image_tag_mutability" {
  description = "Whether image tags can be overwritten. IMMUTABLE prevents a pushed tag (e.g. a git SHA) from being silently replaced."
  type        = string
  default     = "IMMUTABLE"
}

variable "scan_on_push" {
  description = "Run an image vulnerability scan on every push."
  type        = bool
  default     = true
}

variable "max_image_count" {
  description = "Number of most-recent images to retain before the lifecycle policy expires older ones."
  type        = number
  default     = 20
}
