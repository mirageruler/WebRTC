output "region" {
  description = "AWS region"
  value       = var.region
}

output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks_1.cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks_1.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks_1.cluster_security_group_id
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = var.eks_cluster_name
}

output "log_bucket_name" {
  description = "Name of the log bucket"
  value       = var.bucket_name
}

# output "dynamodb_table" {
#   value       = module.remote_state.dynamodb_table
#   description = "The DynamoDB table to manage lock states."
# }

# output "kms_key" {
#   value       = module.remote_state.kms_key
#   description = "The KMS customer master key to encrypt state buckets."
# }

# output "state_bucket" {
#   value       = module.remote_state.state_bucket
#   description = "The S3 bucket to store the remote state file."
# }

# output "replica_bucket" {
#   value       = module.remote_state.replica_bucket
#   description = "The S3 bucket to replicate the state S3 bucket."
# }

# output "terraform_iam_policy" {
#   value       = module.remote_state.terraform_iam_policy
#   description = "The IAM Policy to access remote state environment."
# }

# output "ec2_prometheus" {
#   description = "EC2 Prometheus"
#   value       = resource.aws_instance.prometheus
# }
