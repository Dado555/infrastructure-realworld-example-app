# Key for ECR image encryption
resource "aws_kms_key" "ecr" {
  description         = "Encrypts realworld-backend and realworld-frontend ECR repositories"
  enable_key_rotation = true
}

resource "aws_kms_alias" "ecr" {
  name          = "alias/realworld-ecr"
  target_key_id = aws_kms_key.ecr.key_id
}
