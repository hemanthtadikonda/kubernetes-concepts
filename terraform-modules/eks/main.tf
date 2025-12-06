terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.18"
    }
  }
}


provider "aws" {
  region = var.region
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "example"
  kubernetes_version = "1.30"

  # Optional
  endpoint_public_access = true

  # Optional: Adds the current caller identity as an administrator via cluster access entry
  enable_cluster_creator_admin_permissions = true
  # if you want IAM roles for service accounts
  enable_irsa                    = true

  compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    general = {
      desired_capacity = var.node_desired
      max_capacity     = var.node_max
      min_capacity     = var.node_min
      instance_types   = [var.node_instance_type]
      key_name         = var.ssh_key_name
      additional_tags = {
        Name = "eks-node-general"
      }
    }
  }

  tags = {
    Environment = "staging"
    Terraform   = "true"
  }
}

# Install EKS add-ons (vpc-cni, coredns, cloudwatch observability)
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = module.eks.cluster_id
  addon_name   = "vpc-cni"
  tags = {
    Environment = "staging"
    Terraform   = "true"
  }
}

resource "aws_eks_addon" "coredns" {
  cluster_name = module.eks.cluster_id
  addon_name   = "coredns"
  tags = {
    Environment = "staging"
    Terraform   = "true"
  }
}

resource "aws_eks_addon" "cloudwatch_obs" {
  cluster_name = module.eks.cluster_id
  addon_name   = "amazon-cloudwatch-observability"
  tags = {
    Environment = "staging"
    Terraform   = "true"
  }
}

# Create EFS file system
resource "aws_efs_file_system" "pimcore" {
  creation_token = "${var.fs_name}-${var.environment}"
  encrypted      = true
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name    = var.fs_name
    Project = var.project
    Env     = var.environment
    Terraform   = "true"
  }
}


# Security Group for EFS
resource "aws_security_group" "efs_sg" {
  name        = "${var.fs_name}-${var.environment}-efs-sg"
  description = "Security group for EFS - allows NFS from app nodes"
  vpc_id      = module.vpc.vpc_id


  # Allow NFS from application / EKS worker nodes SG
  ingress {
    description     = "Allow NFS from app/workers"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]      # Pass this value
  }

  # Allow all outbound (default best practice)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.fs_name}-efs-sg"
    Project = var.project
    Env     = var.environment
    Terraform   = "true"
  }
}

# Mount targets for each private subnet
resource "aws_efs_mount_target" "mt" {
  for_each = toset(module.vpc.private_subnets)
  file_system_id  = aws_efs_file_system.pimcore.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs_sg.id]
}


