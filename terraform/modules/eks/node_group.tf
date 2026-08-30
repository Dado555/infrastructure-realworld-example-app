# nodeadm NodeConfig (al2023's bootstrap mechanism, not the old bootstrap.sh shell flags) - only
# to override kubelet's max-pods (see the node_max_pods variable). spec.cluster is populated
# explicitly rather than relying on eks to merge its own auto-generated join config in: verified
# against the real nodeadm source (awslabs/amazon-eks-ami, group is node.eks.aws, NOT the
# nodeadm.k8s.aws some docs summaries claim) and against terraform-aws-modules/terraform-aws-eks's
# actual al2023_user_data.tpl, which always populates this block itself for exactly this reason -
# not worth trusting the auto-merge behavior on a live 3-node cluster's bootstrap path.
locals {
  node_user_data = <<-EOT
    ---
    apiVersion: node.eks.aws/v1alpha1
    kind: NodeConfig
    spec:
      cluster:
        name: ${aws_eks_cluster.this.name}
        apiServerEndpoint: ${aws_eks_cluster.this.endpoint}
        certificateAuthority: ${aws_eks_cluster.this.certificate_authority[0].data}
        cidr: ${aws_eks_cluster.this.kubernetes_network_config[0].service_ipv4_cidr}
      kubelet:
        config:
          maxPods: ${var.node_max_pods}
  EOT
}

# a plain (non-multipart) user_data was rejected outright by a real apply:
# Ec2LaunchTemplateInvalidConfiguration: "User data was not in the MIME multipart format" - eks
# managed node groups require the mime envelope even for a single document, confirmed live, not
# just inferred from terraform-aws-modules/terraform-aws-eks's own use of cloudinit_config here.
data "cloudinit_config" "node" {
  base64_encode = true
  gzip          = false
  boundary      = "MIMEBOUNDARY"

  part {
    content_type = "application/node.eks.aws"
    content      = local.node_user_data
  }
}

# custom sgs suppress eks's automatic cluster-sg attachment, so both are listed explicitly here
resource "aws_launch_template" "node" {
  name_prefix = "${var.name_prefix}-node-"
  user_data   = data.cloudinit_config.node.rendered

  vpc_security_group_ids = [
    aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
    var.node_security_group_id,
  ]

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.name_prefix}-node"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name_prefix}-node-group"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids

  ami_type       = var.node_ami_type
  capacity_type  = var.node_capacity_type
  instance_types = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr,
  ]

  tags = {
    Name = "${var.name_prefix}-node-group"
  }
}
