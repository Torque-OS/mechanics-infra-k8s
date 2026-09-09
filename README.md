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
- **Observability:** Datadog Agent via Helm
- **Modules:** `terraform-aws-modules/vpc/aws` · `terraform-aws-modules/eks/aws`
- **CI/CD:** GitHub Actions

## Architecture

```
Client (internet)
  │
  └─→ API Gateway (HTTP API) ─────────────── the only public address
        │
        ├─ POST /auth           ──→ Lambda (CPF → JWT)          no authorizer
        ├─ GET  /health         ──→ VPC Link                    no authorizer
        ├─ POST /api/auth/login ──→ VPC Link                    no authorizer
        │
        └─ ANY  /{proxy+}       ──→ Lambda authorizer (JWT)
                                          │ allow
                                          ▼
                                       VPC Link
                                          │
AWS Region (us-east-1)                    │  private, no route from the internet
└── VPC                                   ▼
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
  datadog/         # Datadog Agent Helm release (pods, CPU, memory metrics)
  apigateway/      # HTTP API, VPC Link, routes, stage, access logs
```

## Usage

**0. State bucket** — once per account, before the first `init`:

```bash
aws s3api create-bucket --bucket torque-os-tfstate-<account-id> --region us-east-1
aws s3api put-bucket-versioning --bucket torque-os-tfstate-<account-id> \
  --versioning-configuration Status=Enabled
```

Copy `backend.hcl.example` to `backend.hcl` (gitignored) and fill in the bucket name.

**1. Apply** — one pass, cluster and gateway together:

```bash
terraform init -backend-config=backend.hcl
export TF_VAR_datadog_api_key="<your-datadog-api-key>"
terraform apply
terraform output api_gateway_url
```

Terraform owns the load balancer, so nothing here waits for the application. The
gateway answers 503 until pods are ready.

Provisioning the VPC Link takes **10–15 minutes**; the apply will appear to hang on
that resource.

**2. Deploy the application** from the `mechanics-software` repo, in any order:

```bash
aws eks update-kubeconfig --name mechanics-software --region us-east-1
kubectl apply -f k8s/
kubectl rollout status deployment/mechanics-software-api -n mechanics-software
```

The Service is a `NodePort` pinned to `30080`, which is where the target group
forwards. Nodes register through the Auto Scaling group, so no second apply is
needed once pods are healthy.

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
| `enable_api_gateway` | Provision the gateway and the internal load balancer | `true` |
| `enable_datadog` | Install Datadog Agent in EKS via Helm | `true` |
| `datadog_api_key` | Datadog API key. Pass via `TF_VAR_datadog_api_key` | `null` |
| `datadog_site` | Datadog site used by the Agent | `datadoghq.com` |
| `datadog_namespace` | Namespace for Datadog Agent | `datadog` |
| `datadog_release_name` | Helm release name for Datadog Agent | `datadog-agent` |
| `api_service_port` · `api_node_port` | Listener port and the NodePort it forwards to | `8080` · `30080` |
| `gateway_key` | Optional `X-Gateway-Key` secret. Pass via `TF_VAR_gateway_key` | `""` |
| `auth_lambda_name` | Lambda exposed at `POST /auth`. Empty skips the route | `""` |
| `authorizer_lambda_name` | Lambda that authorizes protected routes. Empty leaves every route open | `""` |
| `authorizer_cache_ttl_seconds` | How long a verdict is cached per token. `0` invokes on every request | `300` |
| `public_routes` | Routes that bypass the authorizer | `GET /health`, `POST /api/auth/login` |


## Outputs

| Output | Description |
|--------|-------------|
| `api_gateway_url` | Public base URL of the platform |
| `api_gateway_log_group` | CloudWatch group with gateway access logs |
| `api_gateway_authorizer_id` | Lambda authorizer guarding the protected routes |
| `api_gateway_public_routes` | Routes deliberately reachable without a token |
| `cluster_name` · `cluster_region` · `kubeconfig_command` | Cluster access |
| `datadog_release_name` · `datadog_namespace` · `datadog_release_status` | Datadog deployment status |

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

### Why a REQUEST authorizer and not the native JWT one

The HTTP API ships a built-in JWT authorizer, but it only speaks OIDC: it discovers
the signing keys from a JWKS endpoint and therefore requires asymmetric keys. The
platform signs HS256 with a secret shared between `mechanics-lambda` and
`mechanics-software`, so verification has to run in a Lambda we control.

The authorizer is deliberately the *outer* of two gates — the application revalidates
the same token and enforces roles on top of it. The gateway answers a plain 401 for
anything unsigned, expired or foreign, which keeps that traffic off the cluster
entirely; anything finer grained than "is this token real" belongs to the API.

### Terraform owns the load balancer

The Service used to be a `LoadBalancer`, so Kubernetes created the NLB and Terraform
found it by tag. That inverted the dependency: the gateway could not be provisioned
until the application had been deployed, because a data source on a resource that
does not exist yet fails the plan — which is why the pipeline needed two passes.

The NLB is now a Terraform resource and the Service a `NodePort`. Nodes are attached
through the Auto Scaling group, so scaling registers them automatically. One apply
builds everything, in any order.

### Ordering constraint

`authorizer_lambda_name` is resolved through `data "aws_lambda_function"`, which fails
the plan if the function does not exist. `mechanics-lambda` deploys both functions on
merge to `main`, so that repo has to land **before** this one is applied.

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
- `terraform fmt` + `validate` + `plan` on every PR — the plan always forces
  `enable_datadog=false` and `enable_api_gateway=false`, so PR validation never
  depends on secrets or on infrastructure created outside this repo.
- `terraform apply` on merge to `main`, in stages:
  1. baseline apply with both toggles forced `false`
  2. Datadog Helm install, only if `enable_datadog` resolves to `true`
  3. API Gateway apply, only if `enable_api_gateway` resolves to `true`

State lives in S3, so a runner sees what previous runs created. `TF_STATE_BUCKET` is
required: without it `init` fails, rather than starting from an empty state and
rebuilding infrastructure it then forgets about.

A single apply builds the cluster and the gateway. There is no ordering between this
repository and `mechanics-software`.

Datadog and API Gateway settings are configurable from the repository pipeline
without editing Terraform files.

Configure in GitHub repository settings:

- **Secrets and variables -> Actions -> Secrets**
  - `DATADOG_API_KEY` (required to enable Datadog in CI/CD)
  - `GATEWAY_KEY` (optional, see [Optional: the defence-in-depth header](#optional-the-defence-in-depth-header))
- **Secrets and variables -> Actions -> Variables**
  - `TF_STATE_BUCKET` (**required** — the S3 bucket created in step 0 of [Usage](#usage))
  - `ENABLE_DATADOG` (`true`/`false`, default: `true` when API key exists, otherwise forced to `false`)
  - `DATADOG_SITE` (default: `datadoghq.com`)
  - `DATADOG_NAMESPACE` (default: `datadog`)
  - `DATADOG_RELEASE_NAME` (default: `datadog-agent`)
  - `ENABLE_API_GATEWAY` (`true`/`false`, default: `true`)

  - `AUTH_LAMBDA_NAME` — name of the CPF auth Lambda exposed at `POST /auth`
  - `AUTHORIZER_LAMBDA_NAME` — name of the Lambda authorizer guarding protected routes

The workflow exports these values as `TF_VAR_*` automatically:
- `TF_VAR_datadog_api_key`
- `TF_VAR_enable_datadog`
- `TF_VAR_datadog_site`
- `TF_VAR_datadog_namespace`
- `TF_VAR_datadog_release_name`
- `TF_VAR_enable_api_gateway`
- `TF_VAR_auth_lambda_name`
- `TF_VAR_authorizer_lambda_name`
- `TF_VAR_gateway_key`

Once `ENABLE_API_GATEWAY` is `true`, every subsequent merge to `main` keeps the
gateway applied — there is no need to flip it back after the first successful run.

## Related Repositories

| Repo | Purpose |
|------|---------|
| [mechanics-software](https://github.com/Torque-OS/mechanics-software) | Main API application |
| [mechanics-lambda](https://github.com/Torque-OS/mechanics-lambda) | Lambda CPF auth |
| [mechanics-infra-db](https://github.com/Torque-OS/mechanics-infra-db) | Terraform — RDS PostgreSQL |
