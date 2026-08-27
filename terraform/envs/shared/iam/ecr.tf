module "ecr_backend" {
  source = "../../../modules/ecr-repo"

  repository_name = "realworld-backend"
  kms_key_arn     = aws_kms_key.ecr.arn
  max_image_count = var.ecr_max_image_count
}

module "ecr_frontend" {
  source = "../../../modules/ecr-repo"

  repository_name = "realworld-frontend"
  kms_key_arn     = aws_kms_key.ecr.arn
  max_image_count = var.ecr_max_image_count
}
