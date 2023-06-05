variable "region" {
  description = "This is the cloud hosting region where the application will be deployed. Ex: eu-west-2, ap-southeast-2"
}

variable "env_prefix" {
  description = "This is the environment where your application is deployed. Ex: qa, prod, dev"
}

variable "region_prefix" {
  description = "This is the cloud hosting region prefix where the application will be deployed. Ex: eu, ap, us"
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
}

variable "eks_cluster_nodegroups" {
  description = "Nodegroups of the EKS cluster"
}

variable "eks_cluster_auth_users" {
  description = "IAM users for EKS cluster authentication"
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
}

variable "eks_kms_key_admin" {
  description = "KMS admin for EKS cluster"
  type        = list(string)
}

variable "eks_kms_key_owners" {
  description = "KMS owner for EKS cluster"
  type        = list(string)
}

variable "eks_kms_key_service_users" {
  description = "KMS service users for EKS cluster"
  type        = list(string)
}

variable "eks_kms_key_users" {
  description = "KMS users for EKS cluster"
  type        = list(string)
}

variable "vpc_eks_name" {
  description = "VPC name"
}

variable "vpc_eks_cidr" {
  description = "VPC CIDR range. Ex: 10.0.0.0/16"
}

variable "vpc_eks_private_subnet_cidr" {
  description = "CIDR range of the private subnet. Ex: [\"10.0.0.0/20\", \"10.0.16.0/20\"]"
  type        = list(string)
}

variable "vpc_eks_public_subnet_cidr" {
  description = "CIDR range of the public subnet. Ex: [\"10.0.32.0/20\", \"10.0.48.0/20\"]"
  type        = list(string)
}


variable "cluster_issuer_name" {
  description = "Cluster Issuer Name, used for annotations"
}

variable "cluster_issuer_private_key_secret_name" {
  description = "Name of a secret used to store the ACME account private key"
}

variable "app_namespace" {
  description = "K8s namespace where we host CJC application"
}

variable "peer_1_api_image" {
  description = "API image address for peer 1"
}

variable "peer_2_api_image" {
  description = "API image address for peer 2"
}

variable "bucket" {
  description = "Bucket of s3"
}

variable "profile" {
  description = "AWS profile"
}

variable "ecs_task_execution_role_name" {
  description = "ECS task execution role name"
  default     = "myEcsTaskExecutionRole"
}

variable "ecs_auto_scale_role_name" {
  description = "ECS auto scale role Name"
  default     = "myEcsAutoScaleRole"
}

variable "az_count" {
  description = "Number of AZs to cover in a given region"
  default     = "2"
}

variable "app_image" {
  description = "Docker image to run in the ECS cluster"
  default     = "bradfordhamilton/crystal_blockchain:latest"
}

variable "app_port" {
  description = "Port exposed by the docker image to redirect traffic to"
  default     = 9000
}

variable "app_count" {
  description = "Number of docker containers to run"
  default     = 1
}

variable "health_check_path" {
  default = "/"
}

variable "AWS_KEY_ID" {

}

variable "AWS_SECRET_KEY" {

}

variable "AWS_REGION" {

}

variable "bucket_name" {
  default = "webrtc-bucket-log-test"
}
