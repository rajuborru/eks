# Define your provider and region
provider "aws" {
  region = "us-west-2"
}

# Define your VPC and Subnet resources
resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "eks_subnet" {
  vpc_id     = aws_vpc.eks_vpc.id
  cidr_block = "10.0.1.0/24"
}

# Define your EKS cluster resource
resource "aws_eks_cluster" "example" {
  name     = "example-eks-cluster"
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = [aws_subnet.eks_subnet.id]
  }
}

# Define your IAM Role and Policy for the node group
resource "aws_iam_role" "eks_nodegroup_role" {
  name = "eks-nodegroup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "eks_nodegroup_policy" {
  name        = "eks-nodegroup-policy"
  policy      = data.aws_iam_policy_document.eks_nodegroup_policy.json
}

data "aws_iam_policy_document" "eks_nodegroup_policy" {
  statement {
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeRegions",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVolumes",
      "ec2:CreateSecurityGroup",
      "ec2:CreateTags",
      "ec2:CreateVolume",
      "ec2:ModifyInstanceAttribute",
      "ec2:ModifyVolume",
      "ec2:AttachVolume",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:DetachVolume",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteVolume",
      "ec2:DeleteTags",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress"
    ]

    resources = ["*"]
  }
}

# Define your EKS node group resource
resource "aws_eks_node_group" "example" {
  cluster_name    = aws_eks_cluster.example.name
  node_group_name = "example-node-group"

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 3
  }

  remote_access {
    ec2_ssh_key = "my-ssh-key"
    source_security_group_id = aws_security_group.eks_cluster_sg.id
  }

  subnet_ids = [aws_subnet.eks_subnet.id]

  # Attach the IAM role and policy to the node group
  node_group_launch_template {
    name      = "example-node-group-lt"
    version   = "$Latest"
    # ...
  }

  node_group_iam_role = aws_iam_role.eks_nodegroup_role.name
  node_group_iam_policy_arns = [aws_iam_policy.eks_nodegroup_policy.arn]
}

# Define your Security Group to allow communication within the VPC
