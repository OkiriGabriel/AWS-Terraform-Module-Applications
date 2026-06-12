# boiler-plate Operations Runbook

Operational procedures referenced by the Technical Assurance Report. Primary AWS region: **us-east-1** (N. Virginia).

## 1. Pre-launch gates

| Gate | Owner | Evidence required |
|------|-------|-------------------|
| RDS restore test | DevOps | Written RTO/RPO from point-in-time restore in staging |
| ECS rollback drill | DevOps | Deploy log + previous task definition revision restored |
| Pipeline enforcement | Engineering | Branch protection, required reviews, successful main-branch run |
| Monitoring independence | DevOps | CloudWatch/SNS alarm test (monitoring EC2 stopped → alert still fires) |

## 2. RDS backup and restore test

**Before production launch**, perform at least one restore drill:

1. Note latest automated backup time in RDS console (`prod-db`).
2. Restore to a new instance `prod-db-restore-test` (same VPC/security groups).
3. Run application smoke queries (orders, users, vendors sample).
4. Record **actual RTO** (start → app connected) and **actual RPO** (data age vs failure time).
5. Delete test instance after sign-off.

Document results in the change ticket; target RPO ≤ 15 minutes, RTO ≤ 30 minutes per infrastructure docs.

## 3. Redis failure behaviour (single node)

| Area | Expected behaviour |
|------|-------------------|
| Object cache | Cache miss → load from MySQL; higher latency, no data loss |
| Sessions | Users may be logged out if sessions only in Redis; prefer DB-backed sessions for carts where possible |
| Rate limits | Limits reset or fall back to in-process defaults |
| Distributed locks | Short-lived locks may fail open; reconcile idempotent jobs |
| Vendor/city cache | Rebuilt from DB on miss (5 min TTL) |

**HA milestone:** add Redis replica at ~$1500/month revenue (see scaling milestones in `INFRASTRUCTURE_DOCUMENTATION.md`).

## 4. Monitoring stack SPOF

Prometheus/Grafana run on a single EC2 ASG (`min=1`). If that host fails:

- **CloudWatch/SNS alarms** in `monitoring_alerts.tf` still alert (RDS, ALB, ECS, Redis, monitoring ASG).
- Subscribe operations email/Slack to SNS topic `${environment}-dr-alerts`.
- Longer term: Amazon Managed Grafana / AMP or second monitoring AZ.

## 5. Application rollback

### ECS (image rollback)

```bash
aws ecs update-service \
  --cluster boiler-plate-prod-cluster \
  --service prod-frontend-service \
  --task-definition prod-frontend-service:<PREVIOUS_REVISION> \
  --force-new-deployment \
  --region us-east-1
```

Repeat per service. Verify ALB target health before closing incident.

### Database migrations

- Use **expand–contract** migrations for breaking schema changes.
- Take manual snapshot before production migration.
- Rehearse in staging; prepare down migration scripts where safe.
- **Do not** roll back application code without a migration plan—orders/payments data may not reverse cleanly.

## 6. ECS Fargate capacity

- Production uses **on-demand Fargate** (no Spot-only baseline for critical services).
- Set `min_capacity` ≥ 1 per critical service; configure ALB health checks and graceful shutdown (`stopTimeout`).

## 7. Terraform bootstrap

One-time bootstrap (state bucket, Terraform Cloud workspace access) must be documented in a secure runbook with MFA and least-privilege IAM. State: encrypted, locked, no manual console edits.

## 8. CI/CD checklist

- [ ] `AWS_REGION` GitHub secret = `us-east-1`
- [ ] ECR repositories: `boiler-plate/frontend`, `boiler-plate/backend`, `boiler-plate/admin`
- [ ] Branch protection on `main` (required reviews, no bypass)
- [ ] ECR image scan blocks HIGH/CRITICAL before deploy
