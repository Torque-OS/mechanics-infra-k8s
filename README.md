<p align="center">
  <img src="logo.png" alt="Torque-OS" width="220"/>
</p>

# mechanics-infra-k8s

Terraform infrastructure for the Kubernetes cluster (VPC + AWS EKS) and the API Gateway — part of the [Torque-OS](https://github.com/Torque-OS) Mechanics Software platform.

## Overview

Provisions the AWS networking, the EKS cluster that runs the main application, and the API Gateway that fronts it as the platform's single entry point. Outputs the cluster endpoint consumed by the CI/CD pipeline of [mechanics-software](https://github.com/Torque-OS/mechanics-software).

## Tech Stack

- **IaC:** Terraform
- **Cloud:** AWS (VPC, EKS, IAM, API Gateway v2, CloudWatch)
- **Modules:** `terraform-aws-modules/vpc/aws` · `terraform-aws-modules/eks/aws`
- **CI/CD:** GitHub Actions

## Architecture

```
Client
  │
  └─→ API Gateway (HTTP API) ─────────── single entry point
        │
        ├─ POST /auth      ──→ Lambda (CPF → JWT)
        │
        └─ ANY /{proxy+}   ──→ Load Balancer :8080
             + X-Gateway-Key           │
                                       ▼
AWS Region (us-east-1)
└── VPC
    ├── Public Subnets  ──→ NAT Gateway / Load Balancer
    └── Private Subnets ──→ EKS Node Group
                               └── mechanics-software pods
                                     └── HPA (auto-scale)
```

The load balancer created by the `mechanics-software-api` Service has a public DNS
name, so the gateway injects a shared secret (`X-Gateway-Key`) into every proxied
request. The application rejects requests without it, which keeps the gateway as the
only usable way in. See [ADR — single entry point](#single-entry-point).

## Project Structure

```
main.tf            # Root module — wires kubernetes + apigateway
variables.tf
outputs.tf
providers.tf
modules/
  kubernetes/      # VPC + EKS cluster + node group
  apigateway/      # HTTP API, routes, stage, access logs
```

## Usage

The gateway needs the load balancer that Kubernetes creates, so the apply happens in
two passes.

**1. Cluster only** — `api_backend_url` empty skips the gateway entirely:

```bash
terraform init
terraform apply
aws eks update-kubeconfig --name mechanics-software --region us-east-1
```

**2. Deploy the application** (from the `mechanics-software` repo), then read the
load balancer hostname:

```bash
kubectl get svc mechanics-software-api -n mechanics-software \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

**3. Cluster + gateway:**

```bash
export TF_VAR_gateway_key="$(openssl rand -hex 32)"

terraform apply \
  -var="api_backend_url=http://<hostname-from-step-2>:8080" \
  -var="auth_lambda_name=mechanics-lambda"

terraform output api_gateway_url
```

The same `TF_VAR_gateway_key` value must be stored as the `GATEWAY_KEY` GitHub secret
in `mechanics-software`, so the deployed pods accept the gateway's requests.

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region | `us-east-1` |
| `cluster_name` | EKS cluster name — also names the API Gateway | `mechanics-software` |
| `api_backend_url` | Load balancer URL with port. Empty skips the gateway | `""` |
| `gateway_key` | Shared secret injected as `X-Gateway-Key`. Pass via `TF_VAR_gateway_key` | `""` |
| `auth_lambda_name` | Lambda exposed at `POST /auth`. Empty skips the route | `""` |

## Outputs

| Output | Description |
|--------|-------------|
| `api_gateway_url` | Public base URL of the platform |
| `api_gateway_log_group` | CloudWatch group with gateway access logs |
| `cluster_name` · `cluster_region` · `kubeconfig_command` | Cluster access |

## Single entry point

The gateway integrates over `HTTP_PROXY` against the load balancer's public DNS name
rather than through a VPC Link. A VPC Link would require replacing the Classic Load
Balancer that EKS provisions by default with an internal NLB — HTTP API VPC Links do
not support Classic Load Balancers — plus the AWS Load Balancer Controller. The
shared-secret header achieves the same guarantee (no traffic reaches the application
except through the gateway) at a fraction of the moving parts, which matters on a
time-boxed AWS Academy account.

Trade-off: the enforcement lives in the application rather than in the network. The
load balancer still answers TCP connections; it just refuses to serve them.

## AWS Academy notes

- Session credentials expire every ~4h. Re-export `AWS_ACCESS_KEY_ID`,
  `AWS_SECRET_ACCESS_KEY` and `AWS_SESSION_TOKEN` before any `terraform` command.
- Everything is pinned to `us-east-1`.
- Recreating the cluster produces a **new** load balancer hostname — re-apply with the
  updated `api_backend_url`.

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
