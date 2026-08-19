output "api_id" {
  description = "API Gateway identifier"
  value       = aws_apigatewayv2_api.this.id
}

output "api_endpoint" {
  description = "Public base URL of the API Gateway"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "execution_arn" {
  description = "Execution ARN, used to grant invoke permissions"
  value       = aws_apigatewayv2_api.this.execution_arn
}

output "log_group_name" {
  description = "CloudWatch log group holding the access logs"
  value       = aws_cloudwatch_log_group.access.name
}

output "authorizer_id" {
  description = "Identifier of the Lambda authorizer guarding the protected routes, null when none is configured"
  value       = local.authorizer_enabled ? aws_apigatewayv2_authorizer.jwt[0].id : null
}

output "public_route_keys" {
  description = "Routes deliberately left open, bypassing the authorizer"
  value       = local.public_routes
}

output "vpc_link_id" {
  description = "VPC Link carrying traffic from the gateway into the cluster VPC"
  value       = aws_apigatewayv2_vpc_link.this.id
}
