#More info
#EKS with Secrets encryption using KMS key
#https://www.eksworkshop.com/020_prerequisites/kmskey/ 
#https://aws.amazon.com/blogs/containers/using-eks-encryption-provider-support-for-defense-in-depth/

data "aws_eks_cluster" "cjc_eks_1" {
  name = module.eks_1.cluster_id
}

data "aws_eks_cluster_auth" "cjc_eks_1" {
  name = module.eks_1.cluster_id
}

provider "kubernetes" {
  alias                  = "eks_1"
  host                   = data.aws_eks_cluster.cjc_eks_1.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cjc_eks_1.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cjc_eks_1.token
}

module "eks_1" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.0"

  cluster_name    = var.eks_cluster_name
  cluster_version = "1.23"

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  create_kms_key                  = false
  # kms_key_description             = "The key is used to encrypt EKS secrets"
  # kms_key_administrators          = var.eks_kms_key_admin
  # kms_key_owners                  = var.eks_kms_key_owners
  # kms_key_service_users           = var.eks_kms_key_service_users
  # kms_key_users                   = var.eks_kms_key_users

  # cluster_encryption_config = [{
  #   provider_key_arn = module.eks_1.kms_key_arn
  #   resources        = ["secrets"]
  # }]

  vpc_id     = module.vpc_eks.vpc_id
  subnet_ids = module.vpc_eks.private_subnets

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    disk_size      = 20
    instance_types = ["t3.small", "t3.medium"]
  }

  node_security_group_additional_rules = {
    egress_icmp = {
      description = "Egress ICMP"
      protocol    = "icmp"
      from_port   = -1
      to_port     = -1
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }

    egress_http = {
      description = "Egress all TCP to internet"
      protocol    = "tcp"
      from_port   = 0
      to_port     = 65535
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  cluster_enabled_log_types = []

  eks_managed_node_groups = var.eks_cluster_nodegroups

}

# module "eks_auth_1" {
#   source = "aidanmelen/eks-auth/aws"
#   eks    = module.eks_1

#   wait_for_cluster_timeout = 6000
#   map_users                = var.eks_cluster_auth_users
# }

//aws eks --region $(terraform output -raw region) update-kubeconfig --name $(terraform output -raw cluster_id) --profile cjc-terraform
