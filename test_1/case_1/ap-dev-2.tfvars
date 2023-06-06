region           = "ap-southeast-1"
env_prefix       = "dev"
region_prefix    = "ap"
eks_cluster_name = "dev-ap-eks-2"
peer_1_api_image = "390671053954.dkr.ecr.ap-southeast-1.amazonaws.com/webrtc_test_1:5.0"
peer_2_api_image = "390671053954.dkr.ecr.ap-southeast-1.amazonaws.com/webrtc_test_1:5.0"
eks_cluster_nodegroups = {
  dev-ng-1 = {
    min_size     = 1
    max_size     = 5
    desired_size = 1

    instance_types = ["t3.2xlarge"]
    capacity_type  = "SPOT" //ON_DEMAND

    ebs_optimized = true
    block_device_mappings = {
      xvda = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size           = 20
          volume_type           = "gp3"
          encrypted             = true
          encrypted             = true
          delete_on_termination = true
        }
      }
    }
  }
}

eks_cluster_auth_users = [
  {
    userarn  = "arn:aws:iam::390671053954:user/quang@dwarvesv.com"
    username = "quang@dwarvesv.com"
    groups   = ["system:masters"]
  },
  {
    userarn  = "arn:aws:iam::390671053954:user/patt@dwarvesv.com"
    username = "patt@dwarvesv.com"
    groups   = ["system:masters"]
  },
]
eks_kms_key_admin                      = ["arn:aws:iam::390671053954:user/quang@dwarvesv.com", "arn:aws:iam::390671053954:user/patt@dwarvesv.com"]
eks_kms_key_owners                     = ["arn:aws:iam::390671053954:user/quang@dwarvesv.com", "arn:aws:iam::390671053954:user/patt@dwarvesv.com"]
eks_kms_key_service_users              = ["arn:aws:iam::390671053954:user/quang@dwarvesv.com", "arn:aws:iam::390671053954:user/patt@dwarvesv.com"]
eks_kms_key_users                      = ["arn:aws:iam::390671053954:user/quang@dwarvesv.com", "arn:aws:iam::390671053954:user/patt@dwarvesv.com"]
vpc_eks_name                           = "dev-ap-vpc"
vpc_eks_cidr                           = "10.0.0.0/16"
vpc_eks_private_subnet_cidr            = ["10.0.0.0/20", "10.0.16.0/20"]
vpc_eks_public_subnet_cidr             = ["10.0.32.0/20", "10.0.48.0/20"]
cluster_issuer_name                    = "dev-ap-cert-manager-global"
cluster_issuer_private_key_secret_name = "dev-ap-cert-manager-private-key"
app_namespace                          = "webrtc"
bucket                                 = "cjc-terraform-01d0jipp99"
profile                                = "voconic-dwv003"

transit_gateway_name        = "tgw"
transit_gateway_description = "TF test gateway"
AWS_KEY_ID                  = "AWS_KEY_ID"
AWS_SECRET_KEY              = "AWS_SECRET_KEY"
AWS_REGION                  = "AWS_REGION"
bucket_name                 = "webrtc-bucket-log-test"
