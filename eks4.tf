# Define AWS provider
provider "aws" {
  region = "us-west-2"
}

# Define VPC and Subnets
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name = "eks-vpc"
  cidr = "10.0.0.0/16"
  azs = ["us-west-2a", "us-west-2b", "us-west-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets = []
  enable_nat_gateway = false
}

# Define Security Group for EKS cluster
resource "aws_security_group" "eks_cluster_sg" {
  name_prefix = "eks-cluster-sg-"
  vpc_id = module.vpc.vpc_id
}

# Define EKS cluster
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  cluster_name = "eks-cluster"
  subnets = module.vpc.private_subnets
  vpc_id = module.vpc.vpc_id
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
  security_group_ids = [aws_security_group.eks_cluster_sg.id]
  version = "1.20"
}

# Define Security Group for EKS node groups
resource "aws_security_group" "eks_node_sg" {
  name_prefix = "eks-node-sg-"
  vpc_id = module.vpc.vpc_id
}

# Define EKS node group
module "eks_node_group" {
  source = "terraform-aws-modules/eks/aws//modules/node_group"
  cluster_name = module.eks.cluster_id
  subnets = module.vpc.private_subnets
  additional_security_group_ids = [aws_security_group.eks_node_sg.id]
  instance_type = "t3.small"
  desired_capacity = 2
  min_size = 2
  max_size = 4
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# Define Launch Configuration for EKS node group
resource "aws_launch_configuration" "eks_launch_configuration" {
  name_prefix = "eks-node-lc-"
  image_id = "ami-0c94855ba95c71c99"
  instance_type = "t3.small"
  security_groups = [aws_security_group.eks_node_sg.id]
}

# Define Auto Scaling Group for EKS node group
resource "aws_autoscaling_group" "eks_autoscaling_group" {
  name_prefix = "eks-node-asg-"
  launch_configuration = aws_launch_configuration.eks_launch_configuration.id
  vpc_zone_identifier = module.vpc.private_subnets
  min_size = 2
  max_size = 4
  desired_capacity = 2
  target_group_arns = [module.eks_node_group.target_group_arn]
  depends_on = [module.eks_node_group]
}
