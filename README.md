# mechanics-infra-k8s

Terraform infrastructure for the Kubernetes cluster (VPC + AWS EKS) — part of the [Torque-OS](https://github.com/Torque-OS) Mechanics Software platform.

## Overview

Provisions the AWS networking and EKS cluster that runs the main application. Outputs the cluster endpoint consumed by the CI/CD pipeline of [mechanics-software](https://github.com/Torque-OS/mechanics-software).

## Tech Stack

- **IaC:** Terraform
- **Cloud:** AWS (VPC, EKS, IAM)
- **Modules:** `terraform-aws-modules/vpc/aws` · `terraform-aws-modules/eks/aws`
- **CI/CD:** GitHub Actions

## Architecture

```
AWS Region (us-east-1)
└── VPC
    ├── Public Subnets  ──→ NAT Gateway / Load Balancer
    └── Private Subnets ──→ EKS Node Group
                               └── mechanics-software pods
                                     └── HPA (auto-scale)
```

## Project Structure

```
infra/
  main.tf          # Root module — VPC + EKS
  variables.tf
  outputs.tf
  providers.tf
  versions.tf
modules/
  vpc/             # VPC + subnets
  eks/             # EKS cluster + node group
```

## Usage

```bash
cd infra
terraform init
terraform plan
terraform apply
```

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region | `us-east-1` |
| `cluster_name` | EKS cluster name | `mechanics-software` |
| `node_instance_type` | EC2 instance type for nodes | `t3.medium` |
| `desired_nodes` | Desired node count | `2` |

## CI/CD

GitHub Actions pipeline:
- `terraform fmt` + `validate` + `plan` on every PR
- `terraform apply` on merge to `main`

## Related Repositories

| Repo | Purpose |
|------|---------|
| [mechanics-software](https://github.com/Torque-OS/mechanics-software) | Main API application |
| [mechanics-lambda](https://github.com/Torque-OS/mechanics-lambda) | Lambda CPF auth |
| [mechanics-infra-db](https://github.com/Torque-OS/mechanics-infra-db) | Terraform — RDS PostgreSQL |
