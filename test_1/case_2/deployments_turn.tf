resource "kubernetes_daemon_set_v1" "turn" {
  metadata {
    name = "turn"
    namespace = var.webrtc_with_turn_app_namespace
    labels = {
      "app.kubernetes.io/name" = "turn"
      "app.kubernetes.io/instance" = "turn"
      "app.kubernetes.io/version" = "0.0.1"
    }
  }

  provider = kubernetes.eks_webrtc_with_turn

  spec {
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "turn"
        "app.kubernetes.io/instance" = "turn"
        "app.kubernetes.io/version" = "0.0.1"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "turn"
          "app.kubernetes.io/instance" = "turn"
          "app.kubernetes.io/version" = "0.0.1"
        }
      }

      spec {
        host_network = true

        node_selector = {
          nodegroup = "turn"
        }

        container {
          name = "turn"
          image = "coturn/coturn"
          image_pull_policy = "Always"

          port {
            name = "turn-udp"
            container_port = var.turn_port
            host_port = var.turn_port
            protocol = "UDP"
          }

          port {
            name = "turn-tcp"
            container_port = var.turn_port
            host_port = var.turn_port
            protocol = "TCP"
          }

          args = [
            "-v",
          ]
        }
      }
    }
  }
  depends_on = [
    module.eks_webrtc_with_turn, kubernetes_namespace_v1.webrtc_with_turn_namespace
  ]
}

resource "kubernetes_service_v1" "turn" {
  metadata {
    name = "turn"
    namespace = var.webrtc_with_turn_app_namespace
    labels = {
      "app.kubernetes.io/name" = "turn"
      "app.kubernetes.io/instance" = "turn"
      "app.kubernetes.io/version" = "0.0.1"
    }
  }

  provider = kubernetes.eks_webrtc_with_turn

  spec {
    type = "ClusterIP"

    port {
      name = "turn-udp"
      port = var.turn_port
      target_port = var.turn_port
      protocol = "UDP"
    }

    port {
      name = "turn-tcp"
      port = var.turn_port
      target_port = var.turn_port
      protocol = "TCP"
    }

    selector = {
      "app.kubernetes.io/name" = "turn"
      "app.kubernetes.io/instance" = "turn"
      "app.kubernetes.io/version" = "0.0.1"
    }
  }
  depends_on = [kubernetes_namespace_v1.webrtc_with_turn_namespace]
}