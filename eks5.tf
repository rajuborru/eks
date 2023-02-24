provider "aws" {
  region = "us-west-2"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name = "eks-vpc"
  cidr = "10.0.0.0/16"
  azs = ["us-west-2a", "us-west-2b", "us-west-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets = []
  enable_nat_gateway = false
}

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

  // add node group definition
  node_groups = [
    {
      name                        = "worker-group"
      instance_type               = "t3.small"
      asg_desired_capacity        = 2
      additional_security_group_ids = [aws_security_group.worker_nodes_sg.id]
      subnets                     = module.vpc.private_subnets
      tags = {
        Terraform   = "true"
        Environment = "dev"
      }
    }
  ]
}

resource "aws_security_group" "worker_nodes_sg" {
  name_prefix = "worker-nodes-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

  ###############################
  module "worker_nodes" {
  source = "terraform-aws-modules/eks/aws//modules/node_group"

  cluster_name = module.eks.cluster_name
  node_group_name = "worker-group"
  subnets = module.vpc.private_subnets
  instance_type = "t3.small"
  asg_desired_capacity = 2
  additional_security_group_ids = [aws_security_group.worker_nodes_sg.id]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }

  kubelet_extra_args = "--node-labels=node-group=worker-group"
}
