module "webrtc_with_turn_vpc_eks" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.14"

  name = var.webrtc_with_turn_vpc_eks_name
  cidr = var.webrtc_with_turn_vpc_eks_cidr

 # azs             = ["${var.region}a", "${var.region}b"]
  azs             = local.azs
  private_subnets     = [for k, v in local.azs : cidrsubnet(var.webrtc_with_turn_vpc_eks_cidr, 8, k)]
  public_subnets      = [for k, v in local.azs : cidrsubnet(var.webrtc_with_turn_vpc_eks_cidr, 8, k + 4)]

  enable_nat_gateway   = true
  single_nat_gateway   = false //For HA, we can get rid of this param to create NAT in each subnet. 
  enable_dns_hostnames = true

  public_dedicated_network_acl   = true
  public_inbound_acl_rules = local.network_acls["public_inbound"]
  public_outbound_acl_rules = local.network_acls["public_outbound"]

  //https://aws.amazon.com/premiumsupport/knowledge-center/eks-vpc-subnet-discovery/
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/${var.webrtc_with_turn_eks_cluster_name}" = "private"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${var.webrtc_with_turn_eks_cluster_name}" = "public"
  }
}

locals {
  network_acls = {
      public_inbound = [
      {
        rule_number = 100
        rule_action = "allow"
        from_port   = 0
        to_port     = 65535
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
      {
        rule_number = 200
        rule_action = "allow"
        from_port   = 0
        to_port     = 65535
        protocol    = "udp"
        cidr_block  = "0.0.0.0/0"
        },
        ]
        public_outbound = [
      {
        rule_number = 300
        rule_action = "allow"
        from_port   = 0
        to_port     = 65535
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
      {
        rule_number = 400
        rule_action = "allow"
        from_port   = 0
        to_port     = 65535
        protocol    = "udp"
        cidr_block  = "0.0.0.0/0"
      },
    ]
  }

  azs      = slice(data.aws_availability_zones.available.names, 0, 3)
}

data "aws_availability_zones" "available" {}