variable "release_name" {
  description = "RabbitMQ Helm release name"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for RabbitMQ"
  type        = string
}

variable "image" {
  description = "RabbitMQ container image"
  type        = string
  default     = "rabbitmq:4.1-management"
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

  validation {
    condition = alltrue([
      for name in ["os-service", "billing-service", "execution-service"] :
      contains(keys(var.rabbitmq_users), name) &&
      trimspace(var.rabbitmq_users[name].password) != ""
    ])
    error_message = "rabbitmq_users must contain non-empty passwords for os-service, billing-service, and execution-service."
  }
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
