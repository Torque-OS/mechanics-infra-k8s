module "kubernetes" {
  source       = "./modules/kubernetes"
  cluster_name = var.cluster_name
  aws_region   = var.aws_region
}

module "apigateway" {
  count  = var.api_backend_url == "" ? 0 : 1
  source = "./modules/apigateway"

  api_name         = var.cluster_name
  backend_url      = var.api_backend_url
  gateway_key      = var.gateway_key
  auth_lambda_name = var.auth_lambda_name

  tags = {
    Project = var.cluster_name
  }
}
