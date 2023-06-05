resource "kubernetes_namespace_v1" "test_1_namespace" {
  metadata {
    name = var.app_namespace
  }

  provider = kubernetes.eks_1

  depends_on = [
    module.eks_1
  ]
}
