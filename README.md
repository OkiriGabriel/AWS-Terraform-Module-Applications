# AWS Platform Module

[![Terraform CI](https://github.com/OkiriGabriel/AWS-Terraform-Module-Applications/actions/workflows/terraform-ci.yml/badge.svg)](https://github.com/OkiriGabriel/AWS-Terraform-Module-Applications/actions/workflows/terraform-ci.yml)
[![Terraform](https://img.shields.io/badge/Terraform-%E2%89%A51.5-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS provider](https://img.shields.io/badge/AWS%20provider-5.x-FF9900?logo=amazon-aws)](https://registry.terraform.io/providers/hashicorp/aws/latest)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

One module reference deploys a complete, secure AWS platform. You choose **how strict** (`profile`),
**what to run** (`stack`), and the module wires the rest: network, load balancer, TLS, containers, databases,
VPNs, backups, alarms and the account security baseline.

```hcl
module "platform" {
  source = "git::https://github.com/OkiriGabriel/AWS-Terraform-Module-Applications.git?ref=v1.0.0"

  name    = "acme"
  profile = "production"                      # starter | production | regulated
  stack   = ["ecs", "rds", "redis", "vpn"]    # pick what you need

  domain = { name = "app.example.com", zone_id = "Z0123456789" }
  vpn    = { customer_gateway_ip = "198.51.100.10" }
}
```

`terraform apply` prints a `summary`: the URL, what was created, the security controls in force,
an estimated monthly cost per component, and your next steps.

---

## Contents

- [Why this module](#why-this-module)
- [Quick start](#quick-start)
- [Profiles](#profiles)
- [Stack components](#stack-components)
- [Services and auto-wiring](#services-and-auto-wiring)
- [Overrides](#overrides)
- [Guardrails](#guardrails)
- [Organization guardrails (SCPs)](#organization-guardrails-scps)
- [Outputs](#outputs)
- [Inputs reference](#inputs-reference)
- [Security](#security)
- [Deploying applications (CI/CD)](#deploying-applications-cicd)
- [Testing and CI](#testing-and-ci)
- [Repository layout](#repository-layout)
- [Limitations](#limitations)
- [Contributing](#contributing)

---

## Why this module

| Typical module | This module |
|----------------|-------------|
| 80+ variables to read before the first apply | 3 inputs; everything else has a secure default |
| You wire DB hosts, secrets and IAM into your apps | Services receive `DB_*`, `REDIS_*`, `BUCKET_*` and least-privilege access automatically |
| Insecure combinations fail at runtime, or never | The plan **refuses** them, with a message telling you what to change |
| Cost is a surprise on the bill | `summary.estimated_monthly_usd` breaks it down per component before you apply |
| Security services are a separate project | GuardDuty, CloudTrail, Config, Security Hub, CIS alarms and backups come with the profile |
| Org guardrails are hand-written JSON | Named SCP packs (`region-lock`, `cost-guard`, ...) merged to fit AWS's SCP limits |

---

## Quick start

**Prerequisites:** Terraform >= 1.5, AWS credentials for the target account.

```bash
cd examples/starter
terraform init
terraform apply
```

The starter example runs a public nginx service on Fargate Spot with no domain required. Open the
`summary.url` output when the apply finishes.

Ready-to-copy examples:

| Example | What it shows |
|---------|---------------|
| [examples/starter](examples/starter/main.tf) | Cheapest working stack: one web service, HTTP, single NAT |
| [examples/production](examples/production/main.tf) | Web + API, Postgres, Redis, uploads bucket, HTTPS cert + DNS issued automatically, GitHub deploys |
| [examples/regulated](examples/regulated/main.tf) | Everything on: EKS, EFS, site-to-site VPN, Client VPN with SSO, Transit Gateway, CMK everywhere |
| [examples/organization](examples/organization/main.tf) | SCP guardrails and OUs, applied once from the management account |

Using it from your own repository:

```hcl
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.70.0, < 6.0.0" }
  }
  backend "s3" {
    bucket       = "my-terraform-state"
    key          = "acme/prod.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-east-1"
}

module "platform" {
  source  = "git::https://github.com/OkiriGabriel/AWS-Terraform-Module-Applications.git?ref=v1.0.0"
  name    = "acme"
  profile = "production"
  stack   = ["ecs", "rds"]
  domain  = { name = "app.example.com", zone_id = "Z0123456789" }
}

output "summary" {
  value = module.platform.summary
}
```

The module declares no provider or backend, so region, credentials and state location stay in your hands.
Run one module instance per environment (for example a `dev` and a `prod` root, each with its own state).

---

## Profiles

A profile is a bundle of defaults. Every value below can be changed with [`overrides`](#overrides).

| Setting | `starter` | `production` | `regulated` |
|---------|-----------|--------------|-------------|
| Availability zones | 2 | 2 | 3 |
| NAT gateways | 1 shared | 1 per AZ | 1 per AZ |
| Private AWS endpoints (ECR, logs, SSM, ...) | - | - | yes |
| HTTPS required | no | yes | yes |
| WAF (managed rules + rate limit) | - | 2000 req / 5 min / IP | 1000 req / 5 min / IP |
| Customer-managed KMS | - | - | yes, all data and logs |
| ECS capacity | Fargate Spot | Fargate | Fargate |
| ECS Exec (shell into containers) | yes | yes | no |
| Immutable image tags | - | - | yes |
| RDS class / Multi-AZ | db.t4g.micro / no | db.t4g.medium / yes | db.m7g.large / yes |
| RDS backup retention / final snapshot | 1 day / skipped | 7 days / kept | 35 days / kept |
| Redis nodes | 1 x cache.t4g.micro | 2 x cache.t4g.small (failover) | 2 x cache.m7g.large (failover) |
| AWS Backup | - | 35 d daily, 1 y weekly | 90 d daily, 7 y weekly, vault lock |
| GuardDuty / CloudTrail / Access Analyzer | yes | yes | yes |
| Inspector / Security Hub / Config / CIS alarms | - | yes | yes |
| App log retention / audit log retention | 30 d / 90 d | 90 d / 1 y | 1 y / 7 y |
| EKS API endpoint | public | private | private |
| Deletion protection (ALB, RDS) | off | on | on |

---

## Stack components

List any of these in `stack`:

| Component | Creates | Extra input |
|-----------|---------|-------------|
| `ecs` | Fargate cluster, ALB with per-service routing, ECR repo + logs + autoscaling per service, WAF (profile) | `services`, `domain` |
| `eks` | EKS cluster (encrypted secrets, IRSA, control-plane logs), managed node group on AL2023 | `eks` (optional) |
| `rds` | Postgres or MySQL, encrypted, TLS enforced, password managed and rotated by RDS | `database` (optional) |
| `redis` | ElastiCache Redis replication group, encrypted at rest + in transit, AUTH token in Secrets Manager | - |
| `efs` | Encrypted shared file system, TLS-only policy, access point, mount target per AZ | `services.<x>.efs_mount_path` |
| `cdn` | CloudFront distribution in front of a private S3 bucket (Origin Access Control) | - |
| `vpn` | Site-to-site IPsec VPN (IKEv2, AES/SHA-2); terminates on the Transit Gateway if present | `vpn` |
| `client-vpn` | AWS Client VPN for engineers (certificate or SAML/SSO), connection logging | `client_vpn` |
| `transit-gateway` | Transit Gateway with this VPC attached, routes, optional RAM sharing | `transit_gateway` (optional) |

Always created: the VPC (public + private subnet per AZ, free S3/DynamoDB gateway endpoints, flow logs,
locked-down default security group), the alerts SNS topic, alarms and a CloudWatch dashboard for what you deployed.

VPC peerings are created from the `peerings` map, and application buckets from the `buckets` map.

---

## Services and auto-wiring

```hcl
services = {
  web = { port = 3000, desired_count = 2 }                          # catch-all "/*"
  api = { port = 8080, path_patterns = ["/api/*"], health_check_path = "/api/health" }
  admin = {
    port         = 80
    host_headers = ["admin.example.com"]
    secrets      = { STRIPE_KEY = "arn:aws:secretsmanager:us-east-1:111122223333:secret:stripe-AbCdEf" }
  }
}
```

Each service gets an ECR repository, a log group, a target group, a listener rule, CPU + memory autoscaling,
a deployment circuit breaker with automatic rollback, and its own task and execution roles.

**Auto-wired environment.** Based on what is in `stack`, every service receives:

| Variable | Source |
|----------|--------|
| `DB_ENGINE`, `DB_HOST`, `DB_PORT`, `DB_NAME` | `rds` |
| `DB_USERNAME`, `DB_PASSWORD` | injected as secrets from the RDS-managed Secrets Manager secret |
| `REDIS_HOST`, `REDIS_PORT`, `REDIS_TLS=true` | `redis` |
| `REDIS_AUTH_TOKEN` | injected as a secret |
| `BUCKET_<NAME>` | one per entry in `buckets`, with read/write access granted to the task role |
| EFS mounted at `efs_mount_path` | `efs`, over TLS with IAM authorization |
| `APP_NAME`, `APP_ENVIRONMENT`, `AWS_REGION` | always |

Your own `environment` and `secrets` win over auto-wired values with the same name. The execution role
can read exactly the secrets a service references and nothing else.

**Routing.** One service may be the catch-all (`path_patterns = ["/*"]`, the default). Others need specific
`path_patterns` and/or `host_headers`. With no domain (starter only), the ALB serves HTTP; with a domain,
HTTP redirects to HTTPS on TLS 1.3/1.2.

**Images.** Leave `image` unset to deploy `<ecr repo>:latest`, or set a full image URI.

---

## Overrides

Change any profile setting without forking:

```hcl
overrides = {
  rds_instance_class    = "db.r7g.large"
  nat_mode              = "single"        # none | single | per_az
  waf_blocked_countries = ["KP", "IR"]
  log_retention         = 180
}
```

The `settings` output lists every key and its resolved value.

---

## Guardrails

The plan stops with a clear message when a configuration is insecure or incomplete:

| Refused | Message tells you to |
|---------|----------------------|
| `production`/`regulated` with `ecs` but no domain | add `domain` (or use `starter`) |
| `ecs` with no services | define at least one service |
| More than one catch-all service | give the others paths or host headers |
| `vpn` in stack without `vpn` details | set `customer_gateway_ip` |
| `client-vpn` without certificate, or without an auth method | set the certificate, plus mTLS root or SAML |
| `efs_mount_path` without `efs` in stack | add `efs` |
| `regulated` with `kms_cmk = false`, ECS Exec, no `alert_email`, or a public EKS endpoint | remove the override / set the email |
| `nat_mode = "none"` with containers and no private endpoints | enable `interface_endpoints` or keep a NAT |
| Unknown `stack` component, invalid `name` | fix the value |

---

## Organization guardrails (SCPs)

[modules/organization](modules/organization) is applied **once, from the AWS Organizations management account**.
It creates OUs and attaches service control policies built from named packs:

```hcl
module "organization" {
  source = "git::https://github.com/OkiriGabriel/AWS-Terraform-Module-Applications.git//modules/organization?ref=v1.0.0"

  organizational_units = ["Security", "Workloads", "Sandbox"]
  guardrails           = ["baseline", "region-lock", "require-imdsv2", "require-encryption", "cost-guard"]
  allowed_regions      = ["us-east-1", "us-west-2"]
  exempt_principal_arns = [
    "arn:aws:iam::*:role/OrganizationAccountAccessRole",
    "arn:aws:iam::*:role/terraform-deploy",
  ]
  security_account_id = "222233334444" # delegated admin for GuardDuty + Security Hub
}
```

| Pack | Effect |
|------|--------|
| `baseline` | `deny-leave-org` + `deny-root-user` + `protect-security-services` |
| `deny-leave-org` | Accounts cannot leave the organization |
| `deny-root-user` | Member-account root users can do nothing |
| `protect-security-services` | Nobody can stop or delete CloudTrail, GuardDuty, Config, Security Hub, Access Analyzer, or disable EBS default encryption |
| `deny-iam-users` | No IAM users, access keys or console passwords (use SSO and roles) |
| `region-lock` | Only `allowed_regions`; global services stay usable |
| `require-imdsv2` | EC2 instances must use IMDSv2; no downgrades |
| `require-encryption` | EBS, RDS/Aurora and EFS must be created encrypted |
| `cost-guard` | No GPU, metal or very large instances; no Reserved Instance or Savings Plan purchases |

AWS allows 5 SCPs per target, so packs are merged into at most **two** policies. Each one is checked at plan
time against the 5,120-character limit, and the plan also checks that SCPs are enabled in the organization.

> Add the role your pipelines use to run the platform module to `exempt_principal_arns`. Otherwise
> `protect-security-services` will block it from managing GuardDuty, Config and the other security services.

---

## Outputs

| Output | Contents |
|--------|----------|
| `summary` | URL, dashboard link, services, network, security controls, estimated monthly cost per component, next steps |
| `settings` | Every resolved profile setting |
| `vpc` | VPC ID, CIDR, subnet IDs, route tables, NAT public IPs |
| `security_group_ids` | ALB and tasks security groups (to allow from other stacks) |
| `load_balancer` | ALB DNS name, zone ID, ARN |
| `ecs` | Cluster name, service names, task role ARNs |
| `ecr_repositories` | Repository URL per service |
| `database` | Endpoint, port, name, credentials secret ARN |
| `redis` | Primary/reader endpoints, AUTH secret ARN |
| `efs`, `buckets`, `cdn`, `eks` | IDs and names for each component |
| `connectivity` | VPN connection, tunnel IPs, Client VPN endpoint, Transit Gateway, peering IDs |
| `alerts_topic_arn` | SNS topic receiving every alarm |
| `github_deploy_role_arn` | Role for GitHub Actions OIDC deploys |
| `kms_key_arn` | Platform CMK (when `kms_cmk` is on) |

The cost estimate uses us-east-1 on-demand list prices and excludes data transfer and usage-billed services
(GuardDuty, Config, Security Hub, logs, S3, EFS, CloudFront).

---

## Inputs reference

| Input | Default | Description |
|-------|---------|-------------|
| `name` | (required) | Project prefix, 2-12 lowercase chars |
| `environment` | `"prod"` | Environment label, 2-8 chars |
| `profile` | `"production"` | `starter`, `production` or `regulated` |
| `stack` | `["ecs"]` | Components to deploy (see [Stack components](#stack-components)) |
| `overrides` | `{}` | Override any profile setting |
| `services` | one nginx `web` service | ECS services (see [Services](#services-and-auto-wiring)) |
| `domain` | `null` | `{ name, zone_id }` to issue a certificate + DNS record, or `{ name, certificate_arn }` |
| `network` | `10.0.0.0/16` | `{ cidr, az_count, subnet_newbits }`; subnets are carved automatically |
| `database` | Postgres 16, db `app` | `{ engine, engine_version, name, parameters }` |
| `buckets` | `{}` | App buckets, `{ uploads = { versioning = true } }` |
| `vpn` | `null` | `{ customer_gateway_ip, bgp_asn, static_routes }` |
| `client_vpn` | `null` | `{ server_certificate_arn, client_root_certificate_arn or saml_provider_arn, client_cidr, split_tunnel }` |
| `transit_gateway` | `{}` | `{ amazon_side_asn, routes, share_with_principals }` |
| `peerings` | `{}` | `{ name = { vpc_id, cidr, route_table_ids, peer_owner_id, peer_region } }` |
| `eks` | 1.34, t3.large x2 | `{ version, instance_types, min_size, desired_size, max_size, public_access_cidrs }` |
| `alert_email` | `""` | Email for alarms, GuardDuty and Inspector findings (required for `regulated`) |
| `account_baseline` | `true` | Manage account-level security services; set `false` on all but one environment per account |
| `github_repository` | `""` | `"owner/repo"` to create the OIDC deploy role |
| `github_oidc_subjects` | main branch only | Allowed OIDC subject patterns |
| `create_github_oidc_provider` | `true` | Set `false` if the account already has the GitHub OIDC provider |
| `tags` | `{}` | Extra tags on every resource |

---

## Security

| Area | Controls |
|------|----------|
| Audit | Multi-region CloudTrail with log file validation, KMS-encrypted, TLS-only bucket, CloudWatch Logs; 15 CIS Benchmark alarms (root use, console login without MFA, IAM/SG/NACL/route/VPC/Organizations changes, ...) |
| Detection | GuardDuty (S3, EBS malware, RDS logins, ECS/EKS runtime), Inspector, Security Hub (AWS FSBP + CIS v3.0), AWS Config, IAM Access Analyzer |
| Network | Private subnets for all workloads and data; data stores reachable only from the tasks/EKS/VPN security groups; flow logs; locked default security group; no SSH anywhere |
| Edge | WAF (IP reputation, common rules, known bad inputs, SQLi, rate limiting), TLS 1.3/1.2 policy, invalid headers dropped, logs with `authorization`/`cookie` redacted |
| Encryption | RDS, Redis, EFS, S3, EBS, ECR, Secrets Manager, backups; CMK everywhere in `regulated`; TLS enforced by RDS, Redis, EFS and S3 policies |
| Secrets | RDS password created and rotated by RDS, never in Terraform state; per-service secret access |
| Identity | Least-privilege task roles, ECS Exec instead of SSH, GitHub OIDC instead of access keys |
| Recovery | AWS Backup by tag (RDS, EFS), weekly cold storage, vault lock in `regulated`, RDS final snapshots |

Shared accounts: account-level services (GuardDuty, Security Hub, Config, CloudTrail, EBS default encryption)
can only exist once per account and region. If several environments share one account, set
`account_baseline = false` on all but one of them.

---

## Deploying applications (CI/CD)

1. Set `github_repository = "owner/app-repo"`. The module creates an OIDC role that only the `main` branch
   can assume. It can push to this stack's ECR repos and roll this stack's ECS services, nothing else.
2. Copy [.github/workflows/deploy-ecs.yml.txt](.github/workflows/deploy-ecs.yml.txt) into the application
   repo as `.github/workflows/deploy.yml` and set the repository variables listed at its top from the module outputs.
3. Each push builds an image tagged with the commit SHA and deploys it. The ECS circuit breaker rolls back
   automatically when a deployment fails.

With `github_repository` set, services default to `deployed_by_ci = true`. Terraform keeps managing the task
definition (env vars, secrets, roles, EFS), CI decides which revision runs, and `terraform apply` never rolls back
an image CI deployed.

---

## Testing and CI

The module ships with `terraform test` suites that run every profile end to end and check each guardrail
against a mocked AWS provider. They need no credentials, create nothing, and finish in seconds:

```bash
terraform init -backend=false
terraform test                                    # platform module

cd modules/organization
terraform init -backend=false
terraform test                                    # SCP guardrail packs
```

[`.github/workflows/terraform-ci.yml`](.github/workflows/terraform-ci.yml) runs on every push to any branch,
every pull request, and on demand:

| Job | Checks |
|-----|--------|
| Format and Lint | `terraform fmt`, TFLint (Terraform recommended + AWS ruleset), module file layout |
| Init and Validate | `init` + `validate` for the root module, the organization module and every example |
| Tests (mocked AWS) | Both `terraform test` suites |
| Secret Scanning | Gitleaks over the full git history |
| IaC Security Scanning | Checkov, results uploaded to **Security > Code scanning** |
| CI passed | Single required check for branch protection |

---

## Repository layout

```
.
├── versions.tf          # Terraform + provider requirements (no provider/backend: this is a module)
├── variables.tf         # Inputs
├── locals.tf            # Profiles -> settings, naming, network math
├── guardrails.tf        # Plan-time refusals
├── network.tf           # VPC + security groups
├── edge.tf              # ALB, ACM certificate, DNS, WAF
├── ecs.tf               # Cluster, ECR, services, auto-wiring
├── eks.tf               # EKS
├── data.tf              # RDS, Redis, EFS, app buckets, CDN
├── connectivity.tf      # Site-to-site VPN, Client VPN, Transit Gateway, peering
├── security.tf          # GuardDuty, Inspector, Security Hub, Config, CloudTrail, CIS alarms, Access Analyzer
├── observability.tf     # Alerts topic, alarms, dashboard
├── backup.tf            # AWS Backup plan + vault
├── kms.tf               # Platform CMK
├── cicd.tf              # GitHub OIDC deploy role
├── outputs.tf           # summary, cost estimate, building-block outputs
├── modules/             # Building blocks (usable on their own via //modules/<name>)
│   ├── organization/    # SCP guardrail packs, OUs, delegated security admin
│   ├── vpc/  security_groups/  ecs_service/  rds/  elasticache/  s3/
│   ├── eks/  cloudfront_static/  vpn/  transit_gateway/  vpc_peering/
│   └── guardduty/  inspector/  alb/  dynamodb/
├── examples/            # starter, production, regulated, organization
└── tests/               # terraform test suites (mocked provider)
```

---

## Limitations

- **One region per module instance.** For multi-region, call the module once per region with a provider alias.
- **ALB access logs** are not written to S3 yet (WAF logs and CloudWatch metrics are).
- **Redis AUTH token** is generated by Terraform, so it is present in Terraform state. Keep state encrypted
  and access-controlled. The RDS password is not in state.
- **Cost estimates** are list-price approximations for us-east-1. Use the AWS Pricing Calculator for quotes.
- **Releases:** reference a tag (`?ref=v1.0.0`) in production, never a branch.

---

## Contributing

1. Branch from `main`.
2. Make your change and run `terraform fmt -recursive`, `terraform validate` and `terraform test`.
3. Add or update a test in `tests/` when you change behaviour.
4. Open a pull request. CI must be green.

See [CONTRIBUTING.md](CONTRIBUTING.md) and [BRANCHING_STRATEGY.md](BRANCHING_STRATEGY.md).

## License

MIT. See [LICENSE](LICENSE).
