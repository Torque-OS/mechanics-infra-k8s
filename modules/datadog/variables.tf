variable "cluster_name" {
  description = "EKS cluster name used for Datadog tagging"
  type        = string
}

variable "datadog_api_key" {
  description = "Datadog API key"
  type        = string
  sensitive   = true
}

variable "datadog_site" {
  description = "Datadog site used by the Agent"
  type        = string
  default     = "datadoghq.com"
}

variable "namespace" {
  description = "Namespace where Datadog Agent is installed"
  type        = string
  default     = "datadog"
}

variable "release_name" {
  description = "Helm release name for Datadog Agent"
  type        = string
  default     = "datadog-agent"
}

variable "chart_version" {
  description = "Optional Datadog Helm chart version"
  type        = string
  default     = null
}
