locals {
  auth_lambda_enabled = var.auth_lambda_name != ""

  # Static parameter mapping applied to every proxied request. The application
  # refuses requests without this header, which keeps the gateway as the only
  # usable entry point even though the load balancer has a public DNS name.
  gateway_key_header = var.gateway_key != "" ? {
    "overwrite:header.X-Gateway-Key" = var.gateway_key
  } : {}
}

resource "aws_apigatewayv2_api" "this" {
  name          = var.api_name
  protocol_type = "HTTP"
  description   = "Single entry point for the Mechanics Software platform"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Application routes — proxied to the EKS load balancer
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_integration" "eks" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  integration_uri        = "${var.backend_url}/{proxy}"
  payload_format_version = "1.0"
  timeout_milliseconds   = 29000

  request_parameters = local.gateway_key_header
}

resource "aws_apigatewayv2_route" "proxy" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.eks.id}"
}

# ---------------------------------------------------------------------------
# Authentication route — proxied to the CPF Lambda
# ---------------------------------------------------------------------------

data "aws_lambda_function" "auth" {
  count         = local.auth_lambda_enabled ? 1 : 0
  function_name = var.auth_lambda_name
}

resource "aws_apigatewayv2_integration" "auth" {
  count = local.auth_lambda_enabled ? 1 : 0

  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = data.aws_lambda_function.auth[0].invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "auth" {
  count = local.auth_lambda_enabled ? 1 : 0

  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /auth"
  target    = "integrations/${aws_apigatewayv2_integration.auth[0].id}"
}

resource "aws_lambda_permission" "auth" {
  count = local.auth_lambda_enabled ? 1 : 0

  statement_id  = "AllowInvokeFromApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.auth[0].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/POST/auth"
}

# ---------------------------------------------------------------------------
# Stage
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "access" {
  name              = "/aws/apigateway/${var.api_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access.arn
    format = jsonencode({
      requestId        = "$context.requestId"
      requestTime      = "$context.requestTime"
      httpMethod       = "$context.httpMethod"
      path             = "$context.path"
      routeKey         = "$context.routeKey"
      status           = "$context.status"
      responseLatency  = "$context.responseLatency"
      integrationError = "$context.integration.error"
      sourceIp         = "$context.identity.sourceIp"
    })
  }

  default_route_settings {
    detailed_metrics_enabled = true
    throttling_rate_limit    = var.throttling_rate_limit
    throttling_burst_limit   = var.throttling_burst_limit
  }

  tags = var.tags
}
