#More info
#EKS with Secrets encryption using KMS key
#https://www.eksworkshop.com/020_prerequisites/kmskey/ 
#https://aws.amazon.com/blogs/containers/using-eks-encryption-provider-support-for-defense-in-depth/

data "aws_eks_cluster" "cjc_eks_webrtc_with_turn" {
  name = module.eks_webrtc_with_turn.cluster_id
}

data "aws_eks_cluster_auth" "cjc_eks_webrtc_with_turn" {
  name = module.eks_webrtc_with_turn.cluster_id
}

provider "kubernetes" {
  alias                  = "eks_webrtc_with_turn"
  host                   = data.aws_eks_cluster.cjc_eks_webrtc_with_turn.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cjc_eks_webrtc_with_turn.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cjc_eks_webrtc_with_turn.token
  config_path    = "~/.kube/config"
}

module "eks_webrtc_with_turn" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.0"

  cluster_name    = var.webrtc_with_turn_eks_cluster_name
  cluster_version = "1.23"

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  create_kms_key                  = false

  vpc_id     = module.webrtc_with_turn_vpc_eks.vpc_id
  subnet_ids = module.webrtc_with_turn_vpc_eks.private_subnets

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    disk_size      = 20
    instance_types = ["t3.small", "t3.medium"]
  }

 cluster_enabled_log_types = []

  node_security_group_additional_rules = {
    ingress_all = {
      description = "Ingress All"
      protocol    = "-1"
      from_port   = 0
      to_port     = 65535
      type        = "ingress"
      cidr_blocks = ["0.0.0.0/0"]
    }

    egress_all = {
      description = "Egress All"
      protocol    = "-1"
      from_port   = 0
      to_port     = 65535
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  eks_managed_node_groups = {
  dev-ng-offerer = {
    name = "dev-ng-offerer"
    min_size     = 1
    max_size     = 5
    desired_size = 1
    public_ip = false
    subnet_ids = module.webrtc_with_turn_vpc_eks.private_subnets

  # instance_types = ["c5n.9xlarge"]
    ami_type        = "AL2_ARM_64"
    instance_types = ["c6gn.2xlarge"]
    capacity_type  = "SPOT" //ON_DEMAND

    ebs_optimized = true
    block_device_mappings = {
      xvda = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size           = 20
          volume_type           = "gp3"
          encrypted             = true
          delete_on_termination = true
        }
      }
    }
    labels = {
      nodegroup = "offerer"
    }
    tags = {
        Name = "dev-ng-offerer"
    }
  }
  dev-ng-answerer = {
    name = "dev-ng-answerer"
    min_size     = 1
    max_size     = 5
    desired_size = 1
    public_ip = false
    subnet_ids = module.webrtc_with_turn_vpc_eks.private_subnets

  # instance_types = ["c5n.9xlarge"]
    ami_type        = "AL2_ARM_64"
    instance_types = ["c6gn.2xlarge"]
    capacity_type  = "SPOT" //ON_DEMAND

    ebs_optimized = true
    block_device_mappings = {
      xvda = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size           = 20
          volume_type           = "gp3"
          encrypted             = true
          delete_on_termination = true
        }
      }
    }
    labels = {
      nodegroup = "answerer"
     }

     tags = {
        Name = "dev-ng-answerer"
    }
  }
  dev-ng-turn = {
    name = "dev-ng-turn"
    min_size     = 1
    max_size     = 5
    desired_size = 1
    public_ip = true
    subnet_ids = module.webrtc_with_turn_vpc_eks.public_subnets
    security_group_ids = [aws_security_group.turn_sg.id]

  # instance_types = ["t4g.large"]
    ami_type        = "AL2_ARM_64"
    instance_types = ["c6gn.xlarge"]
    capacity_type  = "SPOT" //ON_DEMAND

    ebs_optimized = true
    block_device_mappings = {
      xvda = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size           = 20
          volume_type           = "gp3"
          encrypted             = true
          delete_on_termination = true
        }
      }
    }
    labels = {
      nodegroup = "turn"
    }

    tags = {
        nodegroup = "dev-ng-turn"
    }
  }
  }
}

data "aws_instances" "turn_nodes" {
  filter {
    name   = "tag:nodegroup"
    values = ["dev-ng-turn"]
  }

  depends_on = [
    module.eks_webrtc_with_turn
  ]
}

resource "aws_security_group" "turn_sg" {
  name_prefix = "turn-sg"
  vpc_id      = module.webrtc_with_turn_vpc_eks.vpc_id


  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  depends_on = [
    module.webrtc_with_turn_vpc_eks
  ]
}

output "turn_nodes" {
  value       = join(",", [for i in data.aws_instances.turn_nodes.public_ips : i])
  description = "TURN NODES:"
  depends_on = [
    data.aws_instances.turn_nodes
  ]
}


