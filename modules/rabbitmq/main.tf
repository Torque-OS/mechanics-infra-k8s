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

resource "kubernetes_secret" "definitions" {
  metadata {
    name      = "${var.release_name}-definitions"
    namespace = var.namespace
  }

  data = {
    "load_definition.json" = jsonencode(local.definitions)
  }

  type = "Opaque"
}

resource "helm_release" "rabbitmq" {
  name             = var.release_name
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "rabbitmq"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  atomic          = true
  cleanup_on_fail = true
  timeout         = 600

  set {
    name  = "auth.username"
    value = "os-service"
  }

  set_sensitive {
    name  = "auth.password"
    value = var.rabbitmq_users["os-service"].password
  }

  values = [yamlencode({
    architecture = "replication"

    auth = {
      vhost = "/os"
    }

    loadDefinition = {
      enabled        = true
      existingSecret = kubernetes_secret.definitions.metadata[0].name
      file           = "/app/load_definition.json"
    }

    persistence = {
      enabled      = true
      storageClass = var.storage_class
      size         = var.storage_size
    }

    service = {
      type = "ClusterIP"
    }

    metrics = {
      enabled = true
    }

    podAnnotations = local.metrics_annotations

    commonLabels = {
      "app.kubernetes.io/part-of" = var.cluster_name
      "torque-os/service"         = "rabbitmq"
    }
  })]

  depends_on = [kubernetes_secret.definitions]
}
