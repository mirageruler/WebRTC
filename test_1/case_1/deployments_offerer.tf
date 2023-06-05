resource "kubernetes_deployment_v1" "offerer" {
  metadata {
    name      = "offerer"
    namespace = var.app_namespace

    labels = {
      app = "cjc"
      svc = "offerer"
    }
  }

  provider = kubernetes.eks_1

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "cjc"
        svc = "offerer"
      }
    }

    template {
      metadata {
        labels = {
          app = "cjc"
          svc = "offerer"
        }
      }

      spec {

        container {
          name  = "offerer"
          image = var.peer_2_api_image

          command = ["offer"]
          args    = ["-answer-address", "answerer:60000", "-bucket-name", var.bucket_name]
          port {
            container_port = 50000
          }

          resources {
            limits = {
              cpu    = "300m"
              memory = "512Mi"
            }

            requests = {
              cpu    = "300m"
              memory = "512Mi"
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
    module.eks_1, resource.kubernetes_namespace_v1.test_1_namespace, kubernetes_service_v1.answerer, aws_s3_bucket.test_log_bucket
  ]
}
resource "kubernetes_service_v1" "offerer" {
  metadata {
    name      = "offerer"
    namespace = var.app_namespace

    labels = {
      app = "cjc"
      svc = "offerer"
    }
  }
  provider = kubernetes.eks_1

  spec {
    port {
      name        = "http"
      port        = 50000
      target_port = "50000"
    }

    selector = {
      svc = "offerer"
    }
  }
  depends_on = [kubernetes_namespace_v1.test_1_namespace]
}
