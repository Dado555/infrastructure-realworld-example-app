data "aws_region" "current" {}

# takes s3 costs off the nat gateway
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private_app.id,
    aws_route_table.private_db.id,
  ]

  tags = {
    Name = "${var.name_prefix}-s3-endpoint"
  }
}