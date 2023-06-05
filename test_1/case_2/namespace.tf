resource "kubernetes_namespace_v1" "webrtc_with_turn_namespace" {
  metadata {
    name = var.webrtc_with_turn_app_namespace
  }

  provider = kubernetes.eks_webrtc_with_turn

  depends_on = [
    module.eks_webrtc_with_turn
  ]
}