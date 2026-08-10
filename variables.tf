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

variable "api_backend_url" {
  description = <<-EOT
    Base URL of the load balancer created by the mechanics-software-api Service,
    including the port. The cluster must be up and the Service applied before the
    gateway can be provisioned:

      kubectl get svc mechanics-software-api -n mechanics-software \
        -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

    Leave empty to skip the API Gateway entirely (cluster-only apply).
  EOT
  type        = string
  default     = ""
}

variable "gateway_key" {
  description = "Shared secret the gateway injects as X-Gateway-Key. Must match GATEWAY_KEY in the application. Supply via TF_VAR_gateway_key, never in a committed file."
  type        = string
  sensitive   = true
  default     = ""
}

variable "auth_lambda_name" {
  description = "Name of the deployed CPF authentication Lambda exposed at POST /auth. Empty skips the route."
  type        = string
  default     = ""
}
