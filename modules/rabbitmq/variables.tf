variable "release_name" {
  description = "RabbitMQ Helm release name"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for RabbitMQ"
  type        = string
}

variable "chart_version" {
  description = "Pinned Bitnami RabbitMQ chart version"
  type        = string
}

variable "storage_class" {
  description = "StorageClass used by the RabbitMQ PVC"
  type        = string
}

variable "storage_size" {
  description = "RabbitMQ PVC size"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name used in resource tags"
  type        = string
}

variable "rabbitmq_users" {
  description = "RabbitMQ users and passwords"
  type = map(object({
    password = string
    tags     = optional(string, "")
  }))
  sensitive = true
}

variable "rabbitmq_vhosts" {
  description = "RabbitMQ vhosts"
  type        = set(string)
}

variable "rabbitmq_permissions" {
  description = "RabbitMQ permissions"
  type = list(object({
    user      = string
    vhost     = string
    configure = string
    write     = string
    read      = string
  }))
}
