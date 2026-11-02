output "namespace" {
  description = "Namespace where RabbitMQ is installed"
  value       = var.namespace
}

output "service_name" {
  description = "RabbitMQ Kubernetes service name"
  value       = "${var.release_name}-rabbitmq"
}

output "amqp_endpoint" {
  description = "In-cluster AMQP endpoint"
  value       = "amqp://${var.release_name}-rabbitmq.${var.namespace}.svc.cluster.local:5672"
}

output "management_endpoint" {
  description = "In-cluster RabbitMQ management endpoint"
  value       = "http://${var.release_name}-rabbitmq.${var.namespace}.svc.cluster.local:15672"
}
