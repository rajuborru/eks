resource "aws_eks_node_group" "self_managed_nodes" {
  cluster_name    = aws_eks_cluster.example.name
  node_group_name = "self-managed-nodes"
  node_role_arn   = aws_iam_role.node.arn

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 3
  }

  launch_template {
    name = "self-managed-node-launch-template"
    id   = aws_launch_template.self_managed_nodes.id
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_launch_template" "self_managed_nodes" {
  name_prefix = "self-managed-node-launch-template"
  image_id    = data.aws_ami.eks.id
  instance_type = "t3.small"
  
  # Set your SSH key name for accessing the nodes
  key_name   = "my-ssh-key"
  
  # Additional configurations can be added as per your requirements
  # For example, setting up the worker node to join the EKS cluster
  user_data = <<-EOF
              #!/bin/bash
              set -o xtrace
              /etc/eks/bootstrap.sh ${aws_eks_cluster.example.name} --kubelet-extra-args '--node-labels=nodegroup=self-managed-nodes' ${aws_eks_cluster.example.endpoint} ${aws_iam_role.node.arn}
              EOF

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "optional"
  }
}

data "aws_ami" "eks" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amazon-eks-node-1.21-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["602401143452"] # Amazon EKS AMI Account ID
}

resource "aws_iam_role" "node" {
  name = "self-managed-node-group"

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

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_iam_role_policy_attachment" "node" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name

  depends_on = [
    aws_iam_role.node,
  ]
}
