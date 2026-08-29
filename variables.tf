variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "mechanics-software"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "enable_api_gateway" {
  description = <<-EOT
    Provision the API Gateway. Keep it false on the first apply: the private
    integration targets the load balancer that the mechanics-software-api
    Service creates, so the cluster and the Service must exist first.
  EOT
  type        = bool
  default     = false
}

variable "api_namespace" {
  description = "Namespace of the application Service"
  type        = string
  default     = "mechanics-software"
}

variable "api_service_name" {
  description = "Name of the application Service whose load balancer the gateway targets"
  type        = string
  default     = "mechanics-software-api"
}

variable "api_service_port" {
  description = "Port published by the application Service"
  type        = number
  default     = 8080
}

variable "gateway_key" {
  description = "Optional shared secret the gateway injects as X-Gateway-Key. Defence in depth — the internal load balancer already blocks any other way in. Supply via TF_VAR_gateway_key, never in a committed file."
  type        = string
  sensitive   = true
  default     = ""
}

variable "auth_lambda_name" {
  description = "Name of the deployed CPF authentication Lambda exposed at POST /auth. Empty skips the route."
  type        = string
  default     = ""
}

variable "enable_datadog" {
  description = "Install Datadog Agent via Helm after the EKS cluster is available"
  type        = bool
  default     = true
}

variable "datadog_api_key" {
  description = "Datadog API key. Supply via TF_VAR_datadog_api_key, never in a committed file."
  type        = string
  sensitive   = true
  default     = null

}

variable "datadog_site" {
  description = "Datadog site used by the Agent"
  type        = string
  default     = "datadoghq.com"
}

variable "datadog_namespace" {
  description = "Namespace where the Datadog Agent is installed"
  type        = string
  default     = "datadog"
}

variable "datadog_release_name" {
  description = "Helm release name for the Datadog Agent"
  type        = string
  default     = "datadog-agent"
}

variable "authorizer_lambda_name" {
  description = "Name of the deployed Lambda that authorizes protected routes. Both this and the function itself come from mechanics-lambda, which must be deployed before this is applied. Empty leaves every route open."
  type        = string
  default     = ""
}

variable "authorizer_cache_ttl_seconds" {
  description = "How long API Gateway caches an authorizer verdict for a given token. Zero invokes the Lambda on every request."
  type        = number
  default     = 300
}
