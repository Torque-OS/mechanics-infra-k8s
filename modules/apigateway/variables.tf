variable "api_name" {
  description = "API Gateway name"
  type        = string
}

variable "nlb_listener_arn" {
  description = "ARN of the listener on the internal NLB that the mechanics-software-api Service creates. Private integrations target a listener, not a URL."
  type        = string
}

variable "vpc_link_subnet_ids" {
  description = "Subnets where API Gateway places the VPC Link network interfaces. Use the private subnets that host the cluster nodes."
  type        = list(string)
}

variable "vpc_link_security_group_ids" {
  description = "Security groups attached to the VPC Link interfaces. Must be allowed to reach the node port on the cluster nodes."
  type        = list(string)
}

variable "gateway_key" {
  description = "Optional shared secret injected as X-Gateway-Key. Defence in depth only — the internal load balancer already makes the gateway the sole entry point. Empty disables it."
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
