# General Configuration
region       = "ap-south-1"
environment  = "development"
project_name = "eks-demo"

# Common Tags
common_tags = {
  Environment = "development"
  Project     = "eks-demo"
  ManagedBy   = "terraform"
  Owner       = "devops-team"
  CostCenter  = "engineering"
  Department  = "platform"
}

# EKS Cluster Configuration
cluster_name    = "eks-cluster-demo"
cluster_version = "1.29"

# Cluster Endpoint Access
cluster_endpoint_public_access  = true
cluster_endpoint_private_access = true

# VPC Configuration
vpc_cidr               = "10.0.0.0/16"
private_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24"]
public_subnet_cidrs    = ["10.0.101.0/24", "10.0.102.0/24"]
enable_nat_gateway     = true
single_nat_gateway     = true

# Node Groups Configuration
node_groups = {
  # Primary node group for system workloads
  system = {
    instance_types = ["t2.micro"]
    min_size       = 1
    max_size       = 3
    desired_size   = 2
    ami_type       = "AL2_x86_64"
    capacity_type  = "ON_DEMAND"
    disk_size      = 20
  }
  
  # Application node group (can be scaled up for workloads)
  # application = {
  #   instance_types = ["t3.medium"]
  #   min_size       = 0
  #   max_size       = 5
  #   desired_size   = 1
  #   ami_type       = "AL2_x86_64"
  #   capacity_type  = "ON_DEMAND"
  #   disk_size      = 30
  # }
  
  # Spot instances for cost optimization (uncomment if needed)
  # spot = {
  #   instance_types = ["t3.small", "t3.medium"]
  #   min_size       = 0
  #   max_size       = 5
  #   desired_size   = 2
  #   ami_type       = "AL2_x86_64"
  #   capacity_type  = "SPOT"
  #   disk_size      = 20
  # }
}

# ALB Controller Configuration
alb_controller_version = "1.7.1"
enable_alb_controller  = true
