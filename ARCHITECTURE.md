# Architecture

How the platform module is put together: what talks to what, where the security boundaries are, and how it
behaves when something fails. For usage, see the [README](README.md); for procedures, the
[Operations Runbook](OPERATIONS_RUNBOOK.md).

## 1. Layers

| Layer | Applied from | Scope | Code |
|-------|--------------|-------|------|
| Organization guardrails | Management account, once | SCPs, OUs, delegated security admin | [modules/organization](modules/organization) |
| Account baseline | Each workload account (`account_baseline = true` in one stack per account) | GuardDuty, Inspector, Security Hub, Config, CloudTrail, CIS alarms, Access Analyzer, EBS default encryption | [security.tf](security.tf) |
| Platform | Each environment | Network, edge, compute, data, connectivity, alarms, backups | the root module |

SCPs constrain what any principal in a member account can do (including Terraform), the account baseline
records and detects, and the platform layer builds the workload with secure defaults.

## 2. Request path

```
                    Internet
                       │
                 Route 53 alias  (when domain.zone_id is set)
                       │
        ┌──────────────▼──────────────┐
        │  WAF (production/regulated) │  IP reputation, common rules, bad inputs, SQLi, rate limit
        └──────────────┬──────────────┘
        ┌──────────────▼──────────────┐  public subnets, one per AZ
        │  Application Load Balancer  │  :80 → 301 to :443 · TLS 1.3/1.2 · invalid headers dropped
        └──────────────┬──────────────┘
          host / path rules, catch-all service last
        ┌──────────────▼──────────────┐  private subnets, one per AZ
        │  ECS Fargate services       │  tasks SG: only from ALB SG, on each service's port
        │  (or EKS workloads)         │
        └───┬──────────┬──────────┬───┘
            │          │          │
     ┌──────▼───┐ ┌────▼────┐ ┌───▼────┐
     │ RDS      │ │ Redis   │ │ EFS    │  each SG allows only tasks / EKS nodes / Client VPN
     │ TLS only │ │ TLS+AUTH│ │ TLS+IAM│
     └──────────┘ └─────────┘ └────────┘
            │
   Outbound: NAT gateway(s) → internet · S3/DynamoDB gateway endpoints (free) ·
             interface endpoints for ECR, logs, SSM, Secrets Manager, STS, KMS (regulated)
```

Without a domain (`starter` only) the ALB serves the services directly over HTTP.

## 3. Network

| Item | Value |
|------|-------|
| VPC | `network.cidr` (default `10.0.0.0/16`) |
| Subnets | Carved with `cidrsubnet(cidr, subnet_newbits, i)`. Default newbits 4 gives /20s (4,091 usable IPs each). Public subnets use indexes `0..n-1`, private `8..8+n-1`, leaving room to add tiers later |
| AZs | 2 (`starter`, `production`) or 3 (`regulated`); override with `network.az_count` |
| NAT | `single` (one shared NAT) or `per_az` (one per AZ, and each private route table uses its own AZ's NAT, so an AZ outage cannot cut egress for the others) |
| Default security group | All rules removed (CIS 5.4) |
| Flow logs | All traffic to CloudWatch Logs; retention from the profile |
| Subnet tags | `kubernetes.io/role/elb` and `internal-elb` so EKS load balancers find the right subnets |

### Hybrid connectivity

```
  Office / data centre ──IPsec (2 tunnels)──┐
                                            ▼
  Engineers ──Client VPN (cert or SSO)──► VPC ◄──► Transit Gateway ◄──► other VPCs / accounts (RAM)
                                            ▲
                                       VPC peering (per entry in `peerings`)
```

- Site-to-site VPN terminates on the Transit Gateway when `transit-gateway` is in the stack, otherwise on a
  Virtual Private Gateway with route propagation into the private route tables.
- Client VPN users are placed in their own security group, which the data tier allows. This is how
  administrators reach the database without public endpoints.

## 4. Identity and secrets

| Principal | Can do | How it is limited |
|-----------|--------|-------------------|
| Task execution role (per service) | Pull image, write logs, read the secrets that service references | Secret ARNs computed from the service's own `secrets` map |
| Task role (per service) | Read/write app buckets, ECS Exec channel, EFS mount | Bucket ARNs, EFS access-point condition |
| GitHub deploy role | Push to this stack's ECR repos, register task definitions, update this stack's services, pass `<prefix>-*` roles to ECS | OIDC trust limited to `repo:<owner>/<repo>:ref:refs/heads/main` by default |
| Humans | Shell into containers with `aws ecs execute-command`; databases via Client VPN | No SSH, no bastion, no public data endpoints |

Credentials:

- **RDS**: `manage_master_user_password` makes RDS create and rotate the master password in Secrets Manager.
  It is never in Terraform state. Services receive it as `DB_USERNAME`/`DB_PASSWORD` secrets.
- **Redis**: Terraform generates the AUTH token and stores it in Secrets Manager. It is also present in
  Terraform state, so protect state accordingly.
- **Encryption keys**: AWS-managed keys by default; one customer-managed platform key (rotation on) when
  `kms_cmk = true`; CloudTrail always uses its own dedicated key.

## 5. Availability and recovery

| Component | `starter` | `production` / `regulated` | Typical behaviour on failure (verify with drills) |
|-----------|-----------|----------------------------|---------------------------------------------------|
| NAT | 1 shared | 1 per AZ | Shared NAT: losing its AZ stops all private egress. Per-AZ: only that AZ is affected |
| ECS services | Fargate Spot, `desired_count` | Fargate on-demand, autoscaling | Tasks spread across AZs; unhealthy tasks replaced; a failed deploy rolls back via the circuit breaker |
| RDS | Single-AZ | Multi-AZ standby | Multi-AZ failover typically takes 1-2 minutes, with the same endpoint. Single-AZ means restoring from backup |
| RDS backups | 1 day PITR, no final snapshot | 7 / 35 days PITR, final snapshot, AWS Backup | Point-in-time restore to a new instance. Transaction logs ship about every 5 minutes, so RPO is about 5 minutes |
| Redis | 1 node | 2 nodes, automatic failover | Single node: cache cold-starts, sessions stored only in Redis are lost. Replicated: replica promoted, same primary endpoint |
| EFS | Regional, multi-AZ mount targets | same, plus AWS Backup | Survives an AZ loss |
| Backups | none | daily + weekly to an encrypted vault; vault lock in `regulated` | Restore from the vault (see runbook) |

Not covered: a full region outage. For that, run a second instance of the module in another region and
replicate data (cross-region RDS read replica / snapshot copy, S3 replication).

## 6. Observability

| Signal | Where |
|--------|-------|
| Metrics dashboard | CloudWatch dashboard named `<name>-<env>`, built from what is deployed (ALB, services, RDS, Redis, alarm status) |
| Alarms | No healthy targets per service, ALB and target 5xx, RDS CPU/storage, Redis CPU/memory, VPN/TGW (module defaults), 15 CIS alarms. All go to the `<name>-<env>-alerts` SNS topic, with OK notifications too |
| Logs | `/ecs/<name>-<env>/<service>`, VPC flow logs, WAF (`aws-waf-logs-<name>-<env>`), CloudTrail, RDS engine logs, Client VPN connections |
| Security findings | GuardDuty and Inspector email high-severity findings; Security Hub aggregates FSBP/CIS results |

## 7. Design decisions

| Decision | Why |
|----------|-----|
| One module with profiles, not many small modules | Most teams need the same 80% wired the same secure way. `overrides` covers the rest without forking |
| Guardrails as plan-time preconditions | Mistakes are cheapest to fix before anything exists; each message says what to change |
| Fargate, not EC2 capacity | No hosts to patch or SSH into; ECS Exec replaces shell access |
| Tag-based AWS Backup selection | New resources opt in by tag instead of by editing a list of ARNs |
| SCP packs merged into two policies | AWS allows 5 SCPs per target; sizes are checked at plan time against the 5,120-character limit |
| `deployed_by_ci` services ignore task-definition drift | CI owns rollouts and Terraform owns configuration, so neither undoes the other |
| No provider or backend in the module | Callers control region, credentials, state, and multi-region layout |
