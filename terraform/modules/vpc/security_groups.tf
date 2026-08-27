# alb-sg: internet-facing
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "alb: public 80/443 in, node-sg only out"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-alb-sg"
  }
}

resource "aws_security_group" "node" {
  name        = "${var.name_prefix}-node-sg"
  description = "eks nodes: app ports from alb-sg, node-to-node, all egress"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-node-sg"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-sg"
  description = "rds: 5432 from node-sg only, no egress"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-rds-sg"
  }
}

# ip-mode target groups hit pod IPs directly - ports come from var.alb_to_node_ports, not hardcoded here
locals {
  # for_each needs string keys; this keeps the port number as the value
  alb_to_node_ports = { for p in var.alb_to_node_ports : tostring(p) => p }
}

# dev-only IP restriction via var.alb_ingress_cidr - widen to 0.0.0.0/0 when actually going live
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = var.alb_ingress_cidr
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "http, redirected to https at the listener"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = var.alb_ingress_cidr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "https"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_node" {
  for_each = local.alb_to_node_ports

  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.node.id
  from_port                    = each.value
  to_port                      = each.value
  ip_protocol                  = "tcp"
  description                  = "alb to node-sg, port ${each.value}"
}

resource "aws_vpc_security_group_ingress_rule" "node_from_alb" {
  for_each = local.alb_to_node_ports

  security_group_id            = aws_security_group.node.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = each.value
  to_port                      = each.value
  ip_protocol                  = "tcp"
  description                  = "from alb-sg, port ${each.value}"
}

# node-to-node traffic - same sg on both sides
resource "aws_vpc_security_group_ingress_rule" "node_self" {
  security_group_id            = aws_security_group.node.id
  referenced_security_group_id = aws_security_group.node.id
  ip_protocol                  = "-1"
  description                  = "node to node"
}

resource "aws_vpc_security_group_egress_rule" "node_all" {
  security_group_id = aws_security_group.node.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "ecr, github, eks add-ons"
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_node" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.node.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "postgres from eks nodes, sg reference only"
}
