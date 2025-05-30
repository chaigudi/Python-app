provider "aws" {
  region = var.region
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"

  name = "eks-vpc"
  cidr = "10.0.0.0/22"

  azs             = ["${var.region}a", "${var.region}b"]
  private_subnets = ["10.0.1.0/27", "10.0.2.0/27"]
  public_subnets  = ["10.0.101.0/27", "10.0.102.0/27"]

  enable_nat_gateway     = false
  single_nat_gateway     = false
  enable_dns_hostnames   = true
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "20.13.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.29"
  subnet_ids      = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id

  eks_managed_node_groups = {
    default = {
      instance_types = ["t2.micro"]
      desired_size   = 2
      min_size       = 1
      max_size       = 3
    }
  }

  enable_irsa = true
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

resource "aws_iam_policy" "alb_ingress" {
  name        = "ALBIngressControllerIAMPolicy"
  description = "Policy for ALB ingress controller"
  policy      = file("${path.module}/iam_policy.json")
}

resource "aws_iam_service_linked_role" "alb" {
  aws_service_name = "elasticloadbalancing.amazonaws.com"
}

resource "aws_iam_role" "alb_ingress_role" {
  name = "alb-ingress-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "eks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_alb_policy" {
  policy_arn = aws_iam_policy.alb_ingress.arn
  role       = aws_iam_role.alb_ingress_role.name
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.1"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }
}
