<p align="center">
  <img src="logo.png" alt="Torque-OS" width="220"/>
</p>

# mechanics-infra-k8s

Terraform infrastructure for the Kubernetes cluster (VPC + AWS EKS) and the API Gateway — part of the [Torque-OS](https://github.com/Torque-OS) Mechanics Software platform.

## Overview

Provisions the AWS networking, the EKS cluster that runs the main application, and the API Gateway that fronts it as the platform's single entry point. Outputs the cluster endpoint consumed by the CI/CD pipeline of [mechanics-software](https://github.com/Torque-OS/mechanics-software).

## Tech Stack

- **IaC:** Terraform
- **Cloud:** AWS (VPC, EKS, IAM, API Gateway v2, VPC Link, CloudWatch)
- **Modules:** `terraform-aws-modules/vpc/aws` · `terraform-aws-modules/eks/aws`
- **CI/CD:** GitHub Actions

## Architecture

```
Client (internet)
  │
  └─→ API Gateway (HTTP API) ─────────────── the only public address
        │
        ├─ POST /auth      ──→ Lambda (CPF → JWT)
        │
        └─ ANY /{proxy+}   ──→ VPC Link
                                  │
AWS Region (us-east-1)            │  private, no route from the internet
└── VPC                           ▼
    ├── Public Subnets  ──→ NAT Gateway
    └── Private Subnets ──→ internal NLB :8080
                               └── EKS Node Group
                                     └── mechanics-software pods
```

The application is unreachable from the internet. The `mechanics-software-api`
Service is annotated as an **internal** NLB, so its DNS name resolves only inside
the VPC, and the gateway reaches it through a VPC Link. Being the sole entry point
is a property of the network, not a rule the application enforces.

## Project Structure

```
main.tf            # Root module — cluster, NLB lookup, VPC Link plumbing
variables.tf
outputs.tf
providers.tf
modules/
  kubernetes/      # VPC + EKS cluster + node group + addons
  apigateway/      # HTTP API, VPC Link, routes, stage, access logs
```

## Usage

The gateway targets the load balancer that Kubernetes creates for the Service, so
it cannot exist before the application is deployed. The apply therefore happens in
two passes.

**1. Cluster only** — `enable_api_gateway` defaults to `false`:

```bash
terraform init
terraform apply
aws eks update-kubeconfig --name mechanics-software --region us-east-1
```

**2. Deploy the application** from the `mechanics-software` repo:

```bash
kubectl apply -f k8s/
kubectl rollout status deployment/mechanics-software-api -n mechanics-software
```

Wait until the NLB reports healthy targets — the gateway needs its listener:

```bash
kubectl get svc mechanics-software-api -n mechanics-software
```

**3. Cluster + gateway** — the NLB is discovered automatically by tag, so there is
no hostname to copy:

```bash
terraform apply -var="enable_api_gateway=true"
terraform output api_gateway_url
```

Provisioning the VPC Link takes **10–15 minutes**; the apply will appear to hang on
that resource.

### Optional: the defence-in-depth header

`gateway_key` makes the gateway stamp every proxied request with `X-Gateway-Key`,
which the application verifies. The network already guarantees the gateway is the
only way in, so this only matters if the Service is ever exposed publicly by
mistake:

```bash
export TF_VAR_gateway_key="$(openssl rand -hex 32)"
```

The same value must be stored as the `GATEWAY_KEY` GitHub secret in
`mechanics-software`. Leaving it unset disables the header on both sides.

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region | `us-east-1` |
| `cluster_name` | EKS cluster name — also names the API Gateway | `mechanics-software` |
| `enable_api_gateway` | Provision the gateway. Keep `false` until the Service exists | `false` |
| `api_namespace` · `api_service_name` · `api_service_port` | How the NLB is located | `mechanics-software` · `mechanics-software-api` · `8080` |
| `gateway_key` | Optional `X-Gateway-Key` secret. Pass via `TF_VAR_gateway_key` | `""` |
| `auth_lambda_name` | Lambda exposed at `POST /auth`. Empty skips the route | `""` |


## Outputs

| Output | Description |
|--------|-------------|
| `api_gateway_url` | Public base URL of the platform |
| `api_gateway_log_group` | CloudWatch group with gateway access logs |
| `cluster_name` · `cluster_region` · `kubeconfig_command` | Cluster access |

## Design notes

### Single entry point

The gateway reaches the cluster over a **VPC Link** into an **internal NLB**. The
Service must be an NLB — HTTP API private integrations cannot target the Classic
Load Balancer EKS would otherwise create — and internal, so it has no public
address at all.

The alternative, integrating against a public load balancer over a shared secret
header, leaves the load balancer answering TCP connections from anywhere and moves
enforcement into the application. That was the original approach here; the VPC Link
replaced it once the account was confirmed to allow one.

## AWS Academy notes

- Session credentials expire every ~4h. Refresh `~/.aws/credentials` with the block
  from **AWS Details → AWS CLI**, including `aws_session_token`, before any
  `terraform` command.
- Everything is pinned to `us-east-1`.
- **Delete the application before destroying.** The NLB belongs to Kubernetes, not
  to Terraform, and `terraform destroy` will fail on `DependencyViolation` while it
  still exists:

  ```bash
  kubectl delete -f k8s/
  terraform destroy
  ```

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
