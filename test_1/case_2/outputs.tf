output "region" {
  description = "AWS region"
  value       = var.region
}

output "offerer_cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks_webrtc_with_turn.cluster_id
}

output "offerer_cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks_webrtc_with_turn.cluster_endpoint
}

output "offerer_cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks_webrtc_with_turn.cluster_security_group_id
}

output "webrtc_with_turn_eks_cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = var.webrtc_with_turn_eks_cluster_name
}

output "log_bucket_name" {
  description = "Name of the log bucket"
  value       = var.bucket_name
}

output "eks_node_groups" {
  description = "webRTC with TURN EKS node groups"
  value = module.eks_webrtc_with_turn.eks_managed_node_groups
}
