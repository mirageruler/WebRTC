resource "kubernetes_deployment_v1" "answerer" {
  metadata {
    name      = "answerer"
    namespace = var.app_namespace

    labels = {
      app = "cjc"
      svc = "answerer"
    }
  }

  provider = kubernetes.eks_1

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

        container {
          name  = "answerer"
          image = var.peer_1_api_image

          command = ["answer"]
          args    = ["-offer-address", "offerer:50000", "-bucket-name", var.bucket_name]
          port {
            container_port = 60000
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
    module.eks_1, resource.kubernetes_namespace_v1.test_1_namespace, kubernetes_service_v1.offerer, aws_s3_bucket.test_log_bucket
  ]
}

resource "kubernetes_service_v1" "answerer" {
  metadata {
    name      = "answerer"
    namespace = var.app_namespace

    labels = {
      app = "cjc"
      svc = "answerer"
    }
  }

  provider = kubernetes.eks_1
  spec {
    port {
      name        = "http"
      port        = 60000
      target_port = "60000"
    }

    selector = {
      svc = "answerer"
    }
  }
  depends_on = [kubernetes_namespace_v1.test_1_namespace]
}

