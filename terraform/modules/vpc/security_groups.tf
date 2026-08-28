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
