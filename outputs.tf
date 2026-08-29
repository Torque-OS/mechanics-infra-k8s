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

output "datadog_release_name" {
  description = "Datadog Helm release name"
  value       = try(one(module.datadog[*].release_name), null)
}

output "datadog_namespace" {
  description = "Namespace where Datadog Agent runs"
  value       = try(one(module.datadog[*].namespace), null)
}

output "datadog_release_status" {
  description = "Status of the Datadog Helm release"
  value       = try(one(module.datadog[*].release_status), null)
}    
    
output "api_gateway_authorizer_id" {
  description = "Lambda authorizer guarding the protected routes — empty when authorizer_lambda_name is unset"
  value       = one(module.apigateway[*].authorizer_id)
}

output "api_gateway_public_routes" {
  description = "Routes deliberately reachable without a token"
  value       = one(module.apigateway[*].public_route_keys)
}
