region           = "us-east-1"
env_prefix       = "dev"
region_prefix    = "ap"
webrtc_with_turn_eks_cluster_name = "dev-ap-eks-webrtc-with-turn"
answerer_eks_cluster_name = "dev-ap-eks-answerer"
peer_1_api_image = "390671053954.dkr.ecr.ap-southeast-1.amazonaws.com/test-answerer:2.1"
peer_2_api_image = "390671053954.dkr.ecr.ap-southeast-1.amazonaws.com/test-offerer:2.1"
image = "390671053954.dkr.ecr.us-east-1.amazonaws.com/webrtc_test_1:arm-1.0"
turn_image = "390671053954.dkr.ecr.us-east-1.amazonaws.com/coturn:latest"

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
webrtc_with_turn_vpc_eks_name                           = "dev-ap-vpc-webrtc-with-turn"
webrtc_with_turn_vpc_eks_cidr                           = "10.0.0.0/16" // VPC CIDR
webrtc_with_turn_vpc_eks_private_subnet_cidr            = ["10.0.1.0/24", "10.0.2.0/24"]  // VPC private subnets
turn_vpc_eks_public_subnet_cidr             = ["10.0.0.0/24"]  // VPC shared public subnet
offerer_vpc_eks_public_subnet_cidr             = ["10.0.3.0/24"]  // VPC public subnet 1
answerer_vpc_eks_public_subnet_cidr = ["10.0.4.0/24"] // VPC public subnet 2
cluster_issuer_name                    = "dev-ap-cert-manager-global"
cluster_issuer_private_key_secret_name = "dev-ap-cert-manager-private-key"
webrtc_with_turn_app_namespace = "webrtc-test1-differ-nodes-with-turn"
answerer_app_namespace = "webrtc-test1-differ-networks-answerer"
bucket                                 = "cjc-terraform-test1-case2"
profile                                = "voconic-dwv003"
turn_port = 3478

AWS_KEY_ID="AKIAVV5OPGSBI6SIU7TI"
AWS_SECRET_KEY="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"
AWS_REGION="us-east-1"
bucket_name="webrtc-with-turn"
