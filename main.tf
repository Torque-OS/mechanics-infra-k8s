module "kubernetes" {
  source       = "./modules/kubernetes"
  cluster_name = var.cluster_name
  aws_region   = var.aws_region
}

module "datadog" {
  count  = var.enable_datadog && var.datadog_api_key != null && length(trimspace(var.datadog_api_key)) > 0 ? 1 : 0
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
}

# Terraform owns the load balancer rather than discovering one Kubernetes made.
# The Service used to create it, so this configuration could not be applied until
# the application had been deployed: a data source lookup on a resource that does
# not exist yet fails the whole plan, and that is what forced the gateway into a
# second apply. Owning it removes the ordering between the two repositories — the
# gateway can be built on an empty cluster and simply answers 503 until pods are
# ready.
resource "aws_lb" "api" {
  count = local.gateway_enabled

  name               = "${var.cluster_name}-api"
  internal           = true
  load_balancer_type = "network"
  subnets            = module.kubernetes.private_subnet_ids

  tags = {
    Project = var.cluster_name
  }
}

resource "aws_lb_target_group" "api" {
  count = local.gateway_enabled

  name        = "${var.cluster_name}-api"
  vpc_id      = module.kubernetes.vpc_id
  target_type = "instance"
  port        = var.api_node_port
  protocol    = "TCP"

  health_check {
    protocol            = "HTTP"
    path                = "/health"
    port                = "traffic-port"
    interval            = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Project = var.cluster_name
  }
}

resource "aws_lb_listener" "api" {
  count = local.gateway_enabled

  load_balancer_arn = aws_lb.api[0].arn
  port              = var.api_service_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api[0].arn
  }
}

resource "aws_autoscaling_attachment" "api" {
  for_each = local.gateway_enabled == 1 ? toset(module.kubernetes.node_group_autoscaling_group_names) : toset([])

  autoscaling_group_name = each.value
  lb_target_group_arn    = aws_lb_target_group.api[0].arn
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
  nlb_listener_arn = aws_lb_listener.api[0].arn
  auth_lambda_name = var.auth_lambda_name

  authorizer_lambda_name       = var.authorizer_lambda_name
  authorizer_cache_ttl_seconds = var.authorizer_cache_ttl_seconds

  vpc_link_subnet_ids         = module.kubernetes.private_subnet_ids
  vpc_link_security_group_ids = [aws_security_group.vpc_link[0].id]

  gateway_key = var.gateway_key

  tags = {
    Project = var.cluster_name
  }
}
