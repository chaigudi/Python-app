# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway     = var.enable_nat_gateway
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = false
  enable_dns_hostnames   = true
  enable_dns_support     = true

  # Tags required for EKS
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = merge(
    var.common_tags,
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
  )
}

# EKS Module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.24.0"  # Updated to newer version to fix deprecation warnings

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # Cluster endpoint configuration
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access

  # IRSA
  enable_irsa = true

  # Cluster access entry
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    for k, v in var.node_groups : k => {
      # Shortened name to avoid length limits
      name           = "${substr(var.cluster_name, 0, 15)}-${k}"
      instance_types = v.instance_types
      
      min_size     = v.min_size
      max_size     = v.max_size
      desired_size = v.desired_size

      # Node group configuration
      ami_type       = v.ami_type
      capacity_type  = v.capacity_type
      disk_size      = v.disk_size

      # Labels for Kubernetes nodes
      labels = merge(
        var.common_tags,
        {
          NodeGroup = k
          Environment = var.environment
        }
      )

      # Node group level tags
      tags = merge(
        var.common_tags,
        {
          Name         = "${substr(var.cluster_name, 0, 15)}-${k}-ng"
          NodeGroup    = k
        }
      )

      # EC2 instance tags
      propagate_tags = ["Environment", "Project", "ManagedBy"]
      
      instance_tags = merge(
        var.common_tags,
        {
          Name                = "${substr(var.cluster_name, 0, 15)}-${k}-node"
          NodeGroup          = k
          "kubernetes.io/cluster/${var.cluster_name}" = "owned"
          "k8s.io/cluster-autoscaler/enabled"         = "true"
          "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
        }
      )
    }
  }

  tags = var.common_tags
}

# Create IRSA for AWS Load Balancer Controller
module "aws_load_balancer_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.34.0"

  role_name = "${substr(var.cluster_name, 0, 20)}-alb-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = var.common_tags

  depends_on = [module.eks]
}

# AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = var.alb_controller_version

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.aws_load_balancer_controller_irsa_role.iam_role_arn
  }

  depends_on = [module.eks, module.aws_load_balancer_controller_irsa_role]
}
