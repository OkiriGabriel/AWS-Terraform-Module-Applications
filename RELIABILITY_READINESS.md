# Reliability Readiness Checklist

Use this before taking a stack built with this module to production. It separates what the module **already
provides** for each profile from what **your team must do**, because no Terraform setting can run a restore drill
or answer a page. The same checklist is in [RELIABILITY_READINESS.csv](RELIABILITY_READINESS.csv) for tracking
in a spreadsheet.

Legend: **yes** = provided by the module · **-** = not provided · **you** = a team action

---

## 1. Single points of failure by profile

| Component | `starter` | `production` | `regulated` | Remove it in `starter` with |
|-----------|-----------|--------------|-------------|-----------------------------|
| NAT gateway | 1 shared (SPOF for egress) | 1 per AZ | 1 per AZ | `overrides.nat_mode = "per_az"` (+~$33/month per AZ) |
| Database | Single-AZ | Multi-AZ | Multi-AZ | `overrides.rds_multi_az = true` |
| Redis | 1 node | 2 nodes, auto-failover | 2 nodes, auto-failover | `overrides.redis_nodes = 2` |
| Compute capacity | Fargate Spot (tasks can be reclaimed) | On-demand | On-demand | `overrides.ecs_capacity = "FARGATE"` |
| Availability zones | 2 | 2 | 3 | `network.az_count = 3` |
| Region | single | single | single | Second module instance in another region (not automated) |

`starter` accepts these on purpose to stay cheap. Move to `production`, or apply the overrides above, before
real customer traffic.

---

## 2. Backups and restore

| Requirement | starter | production | regulated | Your action |
|-------------|---------|------------|-----------|-------------|
| RDS automated backups (PITR) | 1 day | 7 days | 35 days | - |
| RDS final snapshot on destroy | - | yes | yes | - |
| RDS / ALB deletion protection | - | yes | yes | - |
| AWS Backup plan (RDS, EFS by tag) | - | 35 d daily, 1 y weekly | 90 d daily, 7 y weekly | - |
| Backup vault lock | - | - | yes | - |
| Redis snapshots | - | 7 days | 35 days | - |
| S3 versioning (app, config, audit buckets) | yes | yes | yes | - |
| Backups encrypted | yes | yes | yes, CMK | - |
| **RDS restore drill done and timed** | you | you | you | Runbook 4.1, quarterly |
| **EFS / AWS Backup restore drill** | you | you | you | Runbook 4.2 |
| **RTO and RPO agreed in writing** | you | you | you | Typical starting point: RPO 5 min, RTO 30 min |
| Cross-region copy of backups | - | - | - | you, if you need region-level DR |

---

## 3. Deployments

| Requirement | starter | production | regulated | Your action |
|-------------|---------|------------|-----------|-------------|
| Automatic rollback on failed deploy (circuit breaker) | yes | yes | yes | - |
| Health checks per service | yes | yes | yes | Make `health_check_path` check real dependencies |
| CPU + memory autoscaling | yes | yes | yes | Set `min_count` >= 2 for critical services |
| Keyless CI deploys (OIDC) | when `github_repository` set | same | same | - |
| Immutable image tags | - | - | yes | Deploy by commit SHA (the template does) |
| **Rollback drill done** | you | you | you | Runbook 3.2 |
| **Migration practice (expand-contract, snapshot first)** | you | you | you | Runbook 3.3 |
| **Branch protection on `main` requiring "CI passed"** | you | you | you | GitHub > Settings > Branches |

---

## 4. Alerting

| Requirement | starter | production | regulated | Your action |
|-------------|---------|------------|-----------|-------------|
| Alarms: no healthy targets, ALB/target 5xx | yes | yes | yes | - |
| Alarms: RDS CPU + storage, Redis CPU + memory | yes, when in stack | yes | yes | - |
| CIS Benchmark alarms (15) | - | yes | yes | - |
| GuardDuty findings by email | yes, with `alert_email` | yes | yes | - |
| Inspector findings by email | - | yes | yes | - |
| Dashboard | yes | yes | yes | - |
| `alert_email` set | optional | optional | required | Set it |
| **SNS subscription confirmed** | you | you | you | Click the link in the AWS email |
| **Test alert received** | you | you | you | Runbook 8.1 |
| Paging (PagerDuty/Opsgenie/Slack) | - | - | - | you: subscribe to `alerts_topic_arn` |

---

## 5. Security

| Requirement | starter | production | regulated | Your action |
|-------------|---------|------------|-----------|-------------|
| HTTPS with TLS 1.3/1.2 | with `domain` | required | required | - |
| WAF | - | yes | yes | Tune rules against real traffic |
| CloudTrail (multi-region, validated) | yes | yes | yes, 7-year retention | - |
| GuardDuty / Access Analyzer | yes | yes | yes | - |
| Security Hub + Config + Inspector | - | yes | yes | Triage findings weekly |
| Customer-managed KMS | - | - | yes | - |
| No SSH, no public data endpoints | yes | yes | yes | - |
| Organization SCPs | - | - | - | you: apply [modules/organization](modules/organization) from the management account |
| **MFA on all human users; root user locked away** | you | you | you | The `cis-*` alarms fire if this slips |

---

## 6. Incident response

None of these can be automated; all are **you**, for every profile.

| Requirement | Minimum |
|-------------|---------|
| On-call owner | Named primary and secondary, with hours of coverage |
| Escalation path | Who to call when on-call cannot resolve it |
| Incident channel | A dedicated chat channel or bridge |
| Severity levels | P1 / P2 / P3 definitions (template in the runbook, section 9) |
| Post-incident review | Template plus a deadline (5 working days for P1/P2) |
| Runbook reviewed | Team has walked through [OPERATIONS_RUNBOOK.md](OPERATIONS_RUNBOOK.md) |

---

## 7. Suggested upgrade path

| Stage | Change | Approx. added cost / month |
|-------|--------|----------------------------|
| Prototype | `starter` | baseline (about $60 for one small service) |
| First real users | `overrides = { ecs_capacity = "FARGATE", redis_nodes = 2 }`, `min_count = 2` | low |
| Paying customers | `profile = "production"` (Multi-AZ DB, NAT per AZ, WAF, backups, Security Hub) | see `summary.estimated_monthly_usd` |
| Compliance or enterprise contracts | `profile = "regulated"` plus organization SCPs | see `summary.estimated_monthly_usd` |
| Region-level resilience | Second module instance in another region, plus data replication | roughly doubles |

Check the exact figure for your configuration in the `summary.estimated_monthly_usd` output before applying.
