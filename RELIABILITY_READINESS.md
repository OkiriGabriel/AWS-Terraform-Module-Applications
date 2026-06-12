# Reliability Readiness — Production Launch

**Project:** boiler-plate · Single-AZ MVP · May 2026

> Single-AZ RDS, single-node Redis, single NAT gateway, and single monitoring EC2 are deliberate
> trade-offs for a controlled MVP launch. They are not acceptable at aggressive public scale.
> This document defines non-negotiable pre-launch minimums and revenue-gated gates to eliminate
> each SPOF as the business scales.

---

## Summary

| Metric | Count |
|---|---|
| Known SPOFs (all accepted for MVP) | 4 |
| Pre-launch blockers (FAIL) | 14 |
| Requirements already met (PASS) | 14 |
| Partial — needs completion | 1 |

---

## SPOF Register

All four are accepted for the controlled MVP. Each has a defined revenue gate for remediation.

| Component | Failure Mode | Current Config | Blast Radius on Failure | Upgrade Gate |
|---|---|---|---|---|
| RDS MySQL | Single-AZ | db.t3.micro · multi_az=false | ~5–20 min outage on AZ hardware failure | $1k–$5k MRR |
| Redis/ElastiCache | Single node | cache.t3.micro · num_cache_nodes=1 | Session loss + cache miss storm on node failure | $5k–$15k MRR |
| NAT Gateway | Single NAT | single_nat_gateway=true across 2 AZs | All private subnet egress fails if NAT AZ goes down | $1k–$5k MRR |
| Monitoring EC2 | Single instance | t2.small · ASG min=1 max=2 | Grafana/Prometheus blind; ~5–10 min ASG recovery | $5k–$15k MRR |

---

## Pre-Launch Minimums

### Backups — 6/8 passing

| Requirement | Minimum | Current State | Status |
|---|---|---|---|
| RDS automated backups | ≥ 7 days | 7 days (03:00–04:00 UTC) | PASS |
| RDS deletion protection | Enabled | true ✓ | PASS |
| RDS skip_final_snapshot | false | false ✓ | PASS |
| Redis snapshot retention | ≥ 1 day | 1 day (03:00–04:00 UTC) | PASS |
| EFS daily backup (AWS Backup) | Enabled | Daily at 02:00 UTC · 120-day retention | PASS |
| S3 versioning — media & backups | Enabled | Enabled on both buckets | PASS |
| S3 cross-region replication | DR copy | Backups bucket → eu-central-1 | PASS |
| Backup encryption (KMS) | At rest | alias/${env}-boiler-plate-backup | PASS |

> Note: `deletion_protection` and `skip_final_snapshot` were updated as part of this review.

### Restore Testing — 1/6 passing

| Requirement | Minimum | Current State | Status |
|---|---|---|---|
| RDS point-in-time restore | Run + document before launch | Not run / not documented | **FAIL** |
| EFS restore from vault | Run + document before launch | Not run / not documented | **FAIL** |
| RTO target defined | Agreed & documented | Not formally defined | **FAIL** |
| RPO target defined | Agreed & documented | Not formally defined | **FAIL** |
| OPERATIONS_RUNBOOK.md | Exists in repo | Present | PASS |
| Restore runbook (step-by-step) | Step-by-step per resource | Architecture docs exist — procedure incomplete | PARTIAL |

### Alerting — 6/9 active

| Alarm | What It Covers | Terraform File | Status |
|---|---|---|---|
| Monitoring ASG unhealthy | Grafana / Prometheus down | monitoring_alerts.tf | PASS |
| ALB frontend unhealthy targets | Frontend target group health | monitoring_alerts.tf | PASS |
| ECS frontend RunningTaskCount < 1 | Frontend service down | monitoring_alerts.tf | PASS |
| Redis CPUUtilization > 80% | Cache degradation | monitoring_alerts.tf | PASS |
| RDS FreeStorageSpace < 2 GiB | Storage pressure | monitoring_alerts.tf | PASS |
| RDS CPUUtilization > 80% | DB overload | backup_dr.tf | PASS |
| ECS backend RunningTaskCount < 1 | Backend service down — added in this review | monitoring_alerts.tf | PASS |
| RDS DatabaseConnections ≥ 90 | Connection pool exhaustion (max=100) — added in this review | monitoring_alerts.tf | PASS |
| SNS email subscription confirmed | Alert delivery — subscriber must confirm | Manual action required | **FAIL** |

### Incident Response — 1/6 passing

| Requirement | Minimum | Current State | Status |
|---|---|---|---|
| On-call contact defined | Name + phone + hours | Not documented | **FAIL** |
| Incident severity levels | P1/P2/P3 criteria defined | Not defined | **FAIL** |
| Escalation path | Clear chain of escalation | Not documented | **FAIL** |
| War-room channel / tool | Slack / Teams channel created | Not documented | **FAIL** |
| Post-incident review template | Lightweight template | Not documented | **FAIL** |
| OPERATIONS_RUNBOOK.md | Exists in repo | Present | PASS |

> **Highest-risk gap:** 5 of 6 incident response items are unmet. Alarms fire to SNS but the email
> subscription is unconfirmed — alerts may be silently dropped. There is no defined on-call owner.
> An outage today would have no clear responder.

---

## Revenue-Gated Upgrade Path

### Pre-launch — NOW · $0 · Blocker

**Risk:** Data loss on accidental destroy; no incident owner; alerts silently dropped.

| Action |
|---|
| ~~Set deletion_protection = true in vars_enviro_prod.tf~~ ✓ Done |
| ~~Set skip_final_snapshot = false in vars_enviro_prod.tf~~ ✓ Done |
| ~~Add ECS backend RunningTaskCount < 1 alarm to monitoring_alerts.tf~~ ✓ Done |
| ~~Add RDS DatabaseConnections ≥ 90 alarm to monitoring_alerts.tf~~ ✓ Done |
| Confirm SNS topic email subscription (AWS Console — prod-dr-alerts) |
| Run RDS PITR restore test and document result in OPERATIONS_RUNBOOK.md |
| Define RTO / RPO targets and add to runbook |
| Name on-call contact and define P1/P2/P3 severity criteria |

### Early Access · $0–$1k MRR · High · +~$5/mo

**Risk:** 7-day backup window is tight for debugging subtle data corruption; Redis has minimum viable snapshot history.

| Action |
|---|
| Increase backup_retention_period from 7 → 14 days |
| Increase Redis snapshot_retention_limit from 1 → 3 days |
| Run EFS restore test and document result |
| Add post-incident review template to OPERATIONS_RUNBOOK.md |

### Initial Revenue · $1k–$5k MRR · Medium · +~$80/mo

**Risk:** AZ failure causes 5–20 min RDS outage; single NAT gateway takes private subnet egress offline.

| Action |
|---|
| Set multi_az = true in vars_enviro_prod.tf (requires RDS to be ≥ db.t3.small) |
| Upgrade instance_class from db.t3.micro → db.t3.small |
| Set single_nat_gateway = false to provision per-AZ NAT gateways |

### Growth · $5k–$15k MRR · Medium · +~$60/mo

**Risk:** Redis node failure causes session loss; monitoring is still a SPOF; ECS single-task deployments cause brief downtime.

| Action |
|---|
| Replace ElastiCache single node with replication group (1 primary + 1 replica) |
| Set ECS frontend and backend desired_count ≥ 2 |
| Increase monitoring ASG min_size from 1 → 2 (active monitoring HA) |

### Scale · $15k–$50k MRR · Low · +~$120/mo

**Risk:** DB becomes latency bottleneck under read-heavy load; no synthetic monitoring for endpoint health.

| Action |
|---|
| Upgrade RDS to db.t3.medium + enable Performance Insights |
| Add RDS read replica for reporting / analytics queries |
| Add CloudWatch Synthetics canary (endpoint smoke tests every 5 min) |
| Establish quarterly DR drill runbook |

### Committed SLA · $50k+ MRR · Low · +~$250/mo

**Risk:** No defensible uptime SLA without full HA; Redis cluster required for sustained throughput.

| Action |
|---|
| Migrate Redis to cluster mode (3 shards, 1 replica each) |
| Formalize SLA commitments (99.9% or better) in customer contracts |
| Establish dedicated on-call rotation with PagerDuty / OpsGenie |
| Run annual multi-region DR failover drill |

---

## Immediate Terraform Changes Applied

### vars_enviro_prod.tf — rds block

- `deletion_protection` changed `false` → `true` — Terraform will now refuse to destroy the RDS instance without an explicit override
- `skip_final_snapshot` changed `true` → `false` — a final snapshot is taken automatically before any instance deletion

### monitoring_alerts.tf — two alarms added

- `ecs_backend_running_tasks_low` — fires when backend ECS service drops below 1 running task; `treat_missing_data = "breaching"`
- `rds_connections_high` — fires when `DatabaseConnections ≥ 90`; set at 90% of `max_connections = 100` to give lead time before hard connection failures

### Manual action remaining

Navigate to **SNS → Topics → prod-dr-alerts** in the AWS Console and confirm the email subscription.
Until confirmed, all CloudWatch alarms fire into a void.
