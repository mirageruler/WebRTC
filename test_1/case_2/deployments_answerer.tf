resource "kubernetes_deployment_v1" "answerer" {
  metadata {
    name      = "answerer"
    namespace = var.webrtc_with_turn_app_namespace

    labels = {
      app = "cjc"
      svc = "answerer"
    }
  }

  provider = kubernetes.eks_webrtc_with_turn

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "cjc"
        svc = "answerer"
      }
    }

    template {
      metadata {
        labels = {
          app = "cjc"
          svc = "answerer"
        }
      }

      spec {
         node_selector = {
          nodegroup = "answerer"
        }

        container {
          name  = "answerer"
          image = var.image

           command = ["answer"]
           args    = ["-offer-address", "http://${kubernetes_service_v1.offerer.status.0.load_balancer.0.ingress.0.hostname}:50000", "-bucket-name", "${aws_s3_bucket.test_1.bucket}", "-turns", join(",", [for i in data.aws_instances.turn_nodes.public_ips : "${i}:${var.turn_port}"])]
          port {
            container_port = 60000
          }

           resources {
            limits = {
              cpu    = "7"
              memory = "14Gi"
            }

            requests = {
              cpu    = "7"
              memory = "14Gi"
            }
          }
          
          env {
            name  = "AWS_KEY_ID"
            value = var.AWS_KEY_ID
          }

          env {
            name  = "AWS_SECRET_KEY"
            value = var.AWS_SECRET_KEY
          }
          
          env {
            name  = "AWS_REGION"
            value = var.AWS_REGION
          }

          image_pull_policy = "Always"
        }

        restart_policy = "Always"
      }
    }

    strategy {
      type = "RollingUpdate"

      rolling_update {
        max_unavailable = "25%"
        max_surge       = "25%"
      }
    }
  }

  depends_on = [
    module.eks_webrtc_with_turn, kubernetes_namespace_v1.webrtc_with_turn_namespace, data.aws_instances.turn_nodes
  ]
}

resource "kubernetes_service_v1" "answerer" {
  metadata {
     name      = "answerer"
     namespace = var.webrtc_with_turn_app_namespace
     labels = {
       app  = "cjc"
       svc  = "answerer"
     }
   }

   provider = kubernetes.eks_webrtc_with_turn

   spec {
     port {
       name        = "http"
       port        = 60000
       target_port = "60000"
     }

     type = "LoadBalancer"

     selector = {
       svc = "answerer"
     }
   }
   depends_on = [kubernetes_namespace_v1.webrtc_with_turn_namespace]
}
