# used to build the s3 service name below, keeps the module region-agnostic
data "aws_region" "current" {}

# free gateway endpoint - takes ecr layer pulls (s3-backed) off the nat gateway
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

# interface endpoints (ecr.api/ecr.dkr etc) deferred - cost more than the nat they'd replace, revisit only if phase 9 observability shows real nat data-transfer cost
