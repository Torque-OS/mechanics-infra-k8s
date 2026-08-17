output "cluster_name" {
  description = "EKS cluster name"
  value       = module.kubernetes.cluster_name
}

output "cluster_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "kubeconfig_command" {
  description = "Command to update local kubeconfig"
  value       = "aws eks update-kubeconfig --name ${module.kubernetes.cluster_name} --region ${var.aws_region}"
}

output "api_gateway_url" {
  description = "Public entry point of the platform — empty until api_backend_url is set"
  value       = one(module.apigateway[*].api_endpoint)
}

output "api_gateway_log_group" {
  description = "CloudWatch log group with the gateway access logs"
  value       = one(module.apigateway[*].log_group_name)
}
