output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded EKS cluster CA data"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_region" {
  description = "AWS region"
  value       = var.aws_region
}

# Consumed by the API Gateway, which needs to place its VPC Link inside this
# network and reach the nodes across it.

output "vpc_id" {
  description = "VPC hosting the cluster"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnets — where the nodes run and where the VPC Link places its interfaces"
  value       = module.vpc.private_subnets
}

output "vpc_cidr" {
  description = "VPC address range, used to scope the node ingress rule"
  value       = module.vpc.vpc_cidr_block
}

output "node_security_group_id" {
  description = "Security group attached to the cluster nodes"
  value       = module.eks.node_security_group_id
}
