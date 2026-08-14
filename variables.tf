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
