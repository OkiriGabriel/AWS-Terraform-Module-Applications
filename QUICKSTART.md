# Quick Start

Deploy a working stack in about 10 minutes, then grow it one setting at a time.
The full reference is in the [README](README.md).

## 1. Prerequisites

- Terraform >= 1.5 (`terraform version`)
- AWS credentials for the target account (`aws sts get-caller-identity` works)
- Permission to create VPC, ECS, IAM, ELB, CloudWatch and S3 resources

## 2. Create a root configuration

In a new folder (or your infrastructure repo), create `main.tf`:

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.70.0, < 6.0.0" }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "platform" {
  source  = "OkiriGabriel/platform/aws"
  version = "~> 1.0"

  name        = "demo"
  environment = "dev"
  profile     = "starter"
  stack       = ["ecs"]
}

output "summary" {
  value = module.platform.summary
}
```

Or run the ready-made example from this repo: `cd examples/starter`.

## 3. Deploy

```bash
terraform init
terraform plan     # read the plan; guardrails explain anything they refuse
terraform apply
```

When it finishes, `summary.url` serves nginx from Fargate. `summary.estimated_monthly_usd` shows what it costs
(about $60/month for this starter stack, most of it the NAT gateway and load balancer).

## 4. Grow it

Each step is one change and another `terraform apply`:

| Want | Change |
|------|--------|
| Your own app | Push an image to `ecr_repositories["web"]`, remove `image` from the service (or set your image URI) |
| A database | `stack = ["ecs", "rds"]`; services receive `DB_HOST`, `DB_USERNAME`, `DB_PASSWORD` automatically |
| A cache | add `"redis"`; services receive `REDIS_HOST` and `REDIS_AUTH_TOKEN` |
| HTTPS on your domain | `domain = { name = "app.example.com", zone_id = "Z..." }` |
| Production defaults | `profile = "production"` (requires `domain`) |
| Alerts by email | `alert_email = "you@example.com"`, then confirm the email AWS sends |
| VPN to your office | add `"vpn"` and `vpn = { customer_gateway_ip = "<office public IP>" }` |
| Keyless CI deploys | `github_repository = "owner/repo"`, then follow [Deploying applications](README.md#deploying-applications-cicd) |

## 5. Remote state (do this before sharing with a team)

Keep state in S3 with locking. Create the bucket once (versioned, encrypted, public access blocked), then add:

```hcl
terraform {
  backend "s3" {
    bucket       = "my-org-terraform-state"
    key          = "demo/dev.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
```

and run `terraform init -migrate-state`. Use one root folder and one state key per environment.

## 6. Tear down

```bash
terraform destroy
```

`starter` destroys cleanly. `production` and `regulated` enable deletion protection on the load balancer and
database on purpose. To remove them, first apply with
`overrides = { alb_deletion_protect = false, rds_deletion_protect = false }`. Note that `production` and
`regulated` take a final RDS snapshot.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Profile 'production' requires HTTPS...` | Add `domain`, or use `profile = "starter"` while experimenting |
| `BucketAlreadyExists` | Bucket names include your account ID; another stack in the account uses the same `name` + `environment`. Change one of them |
| GuardDuty / Config / Security Hub "already exists" | Another stack manages account-level services. Set `account_baseline = false` here |
| Targets unhealthy, tasks restarting | Check `health_check_path` returns 2xx/3xx and `port` matches the container; read logs in `/ecs/<name>-<env>/<service>` |
| ECS tasks cannot pull images | Private subnets need egress: keep a NAT (`nat_mode`) or enable `interface_endpoints` |
| Certificate stuck in validation | `zone_id` must be the public hosted zone that serves `domain.name` |
