output "release_name" {
  description = "Datadog Helm release name"
  value       = helm_release.datadog_agent.name
}

output "namespace" {
  description = "Namespace where Datadog Agent was installed"
  value       = helm_release.datadog_agent.namespace
}

output "release_status" {
  description = "Status reported by Helm for the Datadog release"
  value       = helm_release.datadog_agent.status
}
