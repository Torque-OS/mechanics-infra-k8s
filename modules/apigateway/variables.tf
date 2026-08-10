variable "api_name" {
  description = "API Gateway name"
  type        = string
}

variable "backend_url" {
  description = "Base URL of the EKS load balancer exposing the application (e.g. http://a1b2c3.us-east-1.elb.amazonaws.com:8080)"
  type        = string
}

variable "gateway_key" {
  description = "Shared secret injected as the X-Gateway-Key header on every proxied request. The application rejects requests that do not carry it, so the load balancer cannot be bypassed. Empty disables the header."
  type        = string
  sensitive   = true
  default     = ""
}

variable "auth_lambda_name" {
  description = "Name of the CPF authentication Lambda exposed at POST /auth. Empty skips the route."
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "CloudWatch retention for API Gateway access logs"
  type        = number
  default     = 7
}

variable "throttling_rate_limit" {
  description = "Steady-state request rate per second across all routes"
  type        = number
  default     = 100
}

variable "throttling_burst_limit" {
  description = "Burst capacity across all routes"
  type        = number
  default     = 200
}

variable "tags" {
  description = "Tags applied to every resource"
  type        = map(string)
  default     = {}
}
