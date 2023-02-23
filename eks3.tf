provider "aws" {
  region = "us-west-2"
}

# create a new VPC
resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"
}

# create two new private subnets in the VPC
resource "aws_subnet" "private_subnet_a" {
  vpc_id     = aws_vpc.eks_vpc.id
  cidr_block = "10.0.1.0/24"
}

resource "aws_subnet" "private_subnet_b" {
  vpc_id     = aws_vpc.eks_vpc.id
  cidr_block = "10.0.2.0/24"
}

# create a new EKS cluster in the VPC
resource "aws_eks_cluster" "eks_cluster" {
  name     = "my-eks-cluster"
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = [aws_subnet.private_subnet_a.id, aws_subnet.private_subnet_b.id]
  }
}

# create a new IAM role for the nodegroup
resource "aws_iam_role" "eks_nodegroup" {
  name = "eks-nodegroup"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# attach the necessary policies to the nodegroup role
resource "aws_iam_role_policy_attachment" "eks_nodegroup_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodegroup.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodegroup.name
}

resource "aws_iam_role_policy_attachment" "eks_ec2_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodegroup.name
}

# create a new nodegroup in one of the private subnets
resource "aws_eks_node_group" "eks_nodegroup" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "my-eks-nodegroup"

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }

  remote_access {
    ec2_ssh_key = "my-ssh-key"
    source_security_group_id = "sg-123456"
  }

  subnet_ids = [aws_subnet.private_subnet_a.id]

  instance_types = ["t2.micro"]
  ami_type       = "AL2_x86_64"
  node_labels = {
    "environment" = "production"
  }

  # use the IAM role created above
  node_role_arn = aws_iam_role.eks_nodegroup.arn
}
