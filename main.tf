module "kubernetes" {
  source       = "./modules/kubernetes"
  cluster_name = var.cluster_name
  aws_region   = var.aws_region
}

module "datadog" {
  count = var.enable_datadog && var.datadog_api_key != null && length(trimspace(var.datadog_api_key)) > 0 ? 1 : 0
  source = "./modules/datadog"

  cluster_name    = module.kubernetes.cluster_name
  datadog_api_key = var.datadog_api_key
  datadog_site    = var.datadog_site
  namespace       = var.datadog_namespace
  release_name    = var.datadog_release_name

  depends_on = [module.kubernetes]
}

locals {
  gateway_enabled = var.enable_api_gateway ? 1 : 0

  service_tag = "${var.api_namespace}/${var.api_service_name}"
}

data "aws_lb" "api" {
  count = local.gateway_enabled

  tags = {
    "kubernetes.io/service-name" = local.service_tag
  }
}

data "aws_lb_listener" "api" {
  count = local.gateway_enabled

  load_balancer_arn = data.aws_lb.api[0].arn
  port              = var.api_service_port
}

resource "aws_security_group" "vpc_link" {
  count = local.gateway_enabled

  name        = "${var.cluster_name}-vpc-link"
  description = "API Gateway VPC Link interfaces"
  vpc_id      = module.kubernetes.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = var.cluster_name
  }
}

resource "aws_security_group_rule" "nodes_from_vpc_link" {
  count = local.gateway_enabled

  type              = "ingress"
  security_group_id = module.kubernetes.node_security_group_id
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  cidr_blocks       = [module.kubernetes.vpc_cidr]
  description       = "NodePort traffic from the API Gateway VPC Link"
}

module "apigateway" {
  count  = local.gateway_enabled
  source = "./modules/apigateway"

  api_name         = var.cluster_name
  nlb_listener_arn = data.aws_lb_listener.api[0].arn
  auth_lambda_name = var.auth_lambda_name

  vpc_link_subnet_ids         = module.kubernetes.private_subnet_ids
  vpc_link_security_group_ids = [aws_security_group.vpc_link[0].id]

  gateway_key = var.gateway_key

  tags = {
    Project = var.cluster_name
  }
}
