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
