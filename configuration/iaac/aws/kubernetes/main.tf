# aws --version
# aws eks --region us-east-1 update-kubeconfig --name in28minutes-cluster
# Uses default VPC and Subnet. Create Your Own VPC and Private Subnets for Prod Usage.
# terraform-backend-state-in28minutes-123
# AKIA4AHVNOD7OOO6T4KI


terraform {
  backend "s3" {
    bucket = "terraform-backend-bucket-ganeshpondy" # Will be overridden from build
    key    = "path/to/my/key" # Will be overridden from build
    region = "us-east-1"
  }
}

resource "aws_default_vpc" "default" {

}

# data "aws_subnet_ids" "subnets" {
#   vpc_id = aws_default_vpc.default.id
# }

# data "aws_subnets" "subnets" {
#   #vpc_id = aws_subnet.selected.vpc_id
# }

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  #load_config_file       = false
  #version                = "~> 1.9"
}

# module "in28minutes-cluster" {
#   source          = "terraform-aws-modules/eks/aws"
#   cluster_name    = "in28minutes-cluster"
#   cluster_version = "1.21"
#   subnet_ids      = ["subnet-0841eb08b7c9a9436", "subnet-0e4d5a439490e29b2"] #CHANGE
#   #subnets = data.aws_subnet_ids.subnets.ids
#   vpc_id          = aws_default_vpc.default.id

#   #vpc_id         = "vpc-1234556abcdef"

#   # node_groups = [
#   #   {
#   #     instance_type = "t2.micro"
#   #     max_capacity  = 5
#   #     desired_capacity = 2
#   #     min_capacity  = 2
#   #   }
#   # ]
#     eks_managed_node_groups = {
#     blue = {}
#     green = {
#       min_size     = 2
#       max_size     = 3
#       desired_size = 2

#       instance_types = ["t2.micro"]
#       capacity_type  = "SPOT"
#     }
#   }
# }

module "in28minutes-cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.0"

  cluster_name    = "in28minutes-cluster"
  cluster_version = "1.21"

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  vpc_id     = aws_default_vpc.default.id
  subnet_ids = ["subnet-0841eb08b7c9a9436", "subnet-0e4d5a439490e29b2"]

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    disk_size      = 10
    instance_types = ["t3.large", "m5.large", "m5n.large", "m5zn.large"]
  }

  eks_managed_node_groups = {
    blue = {}
    green = {
      min_size     = 2
      max_size     = 3
      desired_size = 2

      instance_types = ["t3.large"]
      capacity_type  = "SPOT"
    }
  }
}


data "aws_eks_cluster" "cluster" {
  name = module.in28minutes-cluster.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.in28minutes-cluster.cluster_id
}


# We will use ServiceAccount to connect to K8S Cluster in CI/CD mode
# ServiceAccount needs permissions to create deployments 
# and services in default namespace
resource "kubernetes_cluster_role_binding" "example" {
  metadata {
    name = "fabric8-rbac"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "default"
  }
}

# Needed to set the default region
provider "aws" {
  region  = "us-east-1"
}