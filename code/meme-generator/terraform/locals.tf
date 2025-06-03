locals {
  # Common naming convention
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Cluster specific locals
  cluster_name = var.cluster_name != "" ? var.cluster_name : "${local.name_prefix}-cluster"
  
  # Tags that will be applied to all resources
  common_tags = merge(
    var.common_tags,
    {
      ClusterName = local.cluster_name
      Region      = var.region
      CreatedDate = formatdate("YYYY-MM-DD", timestamp())
    }
  )
  
  # Node group specific tags
  node_group_tags = merge(
    local.common_tags,
    {
      NodeGroupType = "eks-managed"
    }
  )
  
  # Security group rules for additional access (if needed)
  additional_sg_rules = {
    ingress_ssh = {
      description = "SSH access"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [var.vpc_cidr]
    }
  }
  
  # ALB controller settings
  alb_controller_settings = {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    chart_url = "https://aws.github.io/eks-charts"
  }
  
  # Kubernetes labels for node groups
  k8s_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "environment"                  = var.environment
    "project"                      = var.project_name
  }
}
