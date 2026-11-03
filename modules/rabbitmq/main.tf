locals {
  definitions = {
    users = [
      for name, user in var.rabbitmq_users : {
        name              = name
        password          = user.password
        tags              = user.tags
        hashing_algorithm = "rabbit_password_hashing_sha256"
      }
    ]
    vhosts = [
      for name in var.rabbitmq_vhosts : { name = name }
    ]
    permissions = var.rabbitmq_permissions
    parameters  = []
    policies    = []
  }

  metrics_annotations = {
    "ad.datadoghq.com/rabbitmq.checks" = jsonencode([
      {
        openmetrics = {
          init_config = {}
          instances = [
            {
              openmetrics_endpoint = "http://%%host%%:15692/metrics"
              namespace            = "rabbitmq"
              metrics              = ["*"]
            }
          ]
        }
      }
    ])
  }
}

resource "kubernetes_namespace_v1" "rabbitmq" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_secret_v1" "definitions" {
  metadata {
    name      = "${var.release_name}-definitions"
    namespace = kubernetes_namespace_v1.rabbitmq.metadata[0].name
  }

  data = {
    "definitions.json" = jsonencode(local.definitions)
  }

  type = "Opaque"
}

resource "kubernetes_config_map_v1" "config" {
  metadata {
    name      = "${var.release_name}-config"
    namespace = kubernetes_namespace_v1.rabbitmq.metadata[0].name
  }

  data = {
    "rabbitmq.conf"   = "load_definitions = /etc/rabbitmq/definitions/definitions.json"
    "enabled_plugins" = "[rabbitmq_management,rabbitmq_prometheus]."
  }
}

resource "kubernetes_service_v1" "rabbitmq" {
  metadata {
    name      = var.release_name
    namespace = kubernetes_namespace_v1.rabbitmq.metadata[0].name
    labels = {
      "app.kubernetes.io/part-of" = var.cluster_name
      "torque-os/service"         = "rabbitmq"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = var.release_name
    }

    port {
      name        = "amqp"
      port        = 5672
      target_port = 5672
    }

    port {
      name        = "management"
      port        = 15672
      target_port = 15672
    }

    port {
      name        = "metrics"
      port        = 15692
      target_port = 15692
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_stateful_set_v1" "rabbitmq" {
  metadata {
    name      = var.release_name
    namespace = kubernetes_namespace_v1.rabbitmq.metadata[0].name
    labels = {
      "app.kubernetes.io/name"    = var.release_name
      "app.kubernetes.io/part-of" = var.cluster_name
      "torque-os/service"         = "rabbitmq"
    }
  }

  spec {
    service_name = kubernetes_service_v1.rabbitmq.metadata[0].name
    replicas     = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name" = var.release_name
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"    = var.release_name
          "app.kubernetes.io/part-of" = var.cluster_name
          "torque-os/service"         = "rabbitmq"
        }
        annotations = local.metrics_annotations
      }

      spec {
        container {
          name              = "rabbitmq"
          image             = var.image
          image_pull_policy = "IfNotPresent"

          port {
            name           = "amqp"
            container_port = 5672
          }

          port {
            name           = "management"
            container_port = 15672
          }

          port {
            name           = "metrics"
            container_port = 15692
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/rabbitmq/rabbitmq.conf"
            sub_path   = "rabbitmq.conf"
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/rabbitmq/enabled_plugins"
            sub_path   = "enabled_plugins"
          }

          volume_mount {
            name       = "definitions"
            mount_path = "/etc/rabbitmq/definitions"
            read_only  = true
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/rabbitmq"
          }

          readiness_probe {
            exec {
              command = ["rabbitmq-diagnostics", "-q", "ping"]
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          liveness_probe {
            exec {
              command = ["rabbitmq-diagnostics", "-q", "ping"]
            }
            initial_delay_seconds = 60
            period_seconds        = 30
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.config.metadata[0].name
          }
        }

        volume {
          name = "definitions"
          secret {
            secret_name = kubernetes_secret_v1.definitions.metadata[0].name
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "data"
      }

      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = var.storage_class
        resources {
          requests = {
            storage = var.storage_size
          }
        }
      }
    }
  }

  depends_on = [kubernetes_secret_v1.definitions, kubernetes_config_map_v1.config]
}
