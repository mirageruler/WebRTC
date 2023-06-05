module "vpc_eks" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.14"

  name = var.vpc_eks_name
  cidr = var.vpc_eks_cidr

  azs             = ["${var.region}a", "${var.region}b"]
  private_subnets = var.vpc_eks_private_subnet_cidr
  public_subnets  = var.vpc_eks_public_subnet_cidr

  enable_nat_gateway   = true
  single_nat_gateway   = false //For HA, we can get rid of this param to create NAT in each subnet. 
  enable_dns_hostnames = true

  //https://aws.amazon.com/premiumsupport/knowledge-center/eks-vpc-subnet-discovery/
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}
