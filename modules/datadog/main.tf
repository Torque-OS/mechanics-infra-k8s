resource "helm_release" "datadog_agent" {
  name             = var.release_name
  repository       = "https://helm.datadoghq.com"
  chart            = "datadog"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  lifecycle {
    precondition {
      condition     = length(trimspace(coalesce(var.datadog_api_key, ""))) > 0
      error_message = "datadog_api_key must be provided when Datadog is enabled."
    }
  }

  atomic          = true
  cleanup_on_fail = true
  timeout         = 600

  set_sensitive {
    name  = "datadog.apiKey"
    value = var.datadog_api_key
  }

  set {
    name  = "datadog.site"
    value = var.datadog_site
  }

  set {
    name  = "datadog.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "datadog.kubeStateMetricsCore.enabled"
    value = "true"
  }

  set {
    name  = "datadog.kubelet.enabled"
    value = "true"
  }

  set {
    name  = "clusterAgent.enabled"
    value = "true"
  }

  set {
    name  = "datadog.orchestratorExplorer.enabled"
    value = "true"
  }

  set {
    name  = "datadog.processAgent.processCollection"
    value = "true"
  }

  set {
    name  = "datadog.prometheusScrape.enabled"
    value = "true"
  }

  set {
    name  = "datadog.prometheusScrape.serviceEndpoints"
    value = "true"
  }

  set {
    name  = "datadog.prometheusScrape.podAnnotations"
    value = "true"
  }

  set {
    name  = "datadog.logs.enabled"
    value = "true"
  }

  set {
    name  = "datadog.logs.containerCollectAll"
    value = "true"
  }

  set {
    name  = "datadog.apm.instrumentation.enabled"
    value = "true"
  }

  set {
    name  = "datadog.apm.instrumentation.targets[0].language"
    value = "dotnet"
  }

  set {
    name  = "datadog.apm.instrumentation.targets[0].ddTraceVersion"
    value = "3"
    type  = "string"
  }
}
