# Operations Runbook

Procedures for running a stack built with this module. Names follow the module's convention,
`<prefix> = <name>-<environment>` (for example `acme-prod`). Commands assume `AWS_REGION` is set.
Read actual names from the module outputs (`terraform output -json`).

```bash
export AWS_REGION=us-east-1
PREFIX=acme-prod
CLUSTER=$PREFIX
```

---

## 1. Before go-live

| Gate | Evidence |
|:-----|:---------|
| Alerts reach a human | SNS email subscription confirmed; a test alarm received (section 8.1) |
| Database restore drill | Section 4.1 completed; actual RTO/RPO recorded |
| Deployment rollback drill | Section 3.2 completed in a non-production stack |
| Branch protection | `main` requires reviews and the **CI passed** check |
| RTO/RPO agreed | Written targets the business accepts (see [RELIABILITY_READINESS.md](RELIABILITY_READINESS.md)) |
| On-call owner | Named person and escalation path (section 9) |

---

## 2. Access (no SSH)

**Shell into a running container** (ECS Exec; enabled in `starter` and `production`, disabled in `regulated`):

```bash
TASK=$(aws ecs list-tasks --cluster $CLUSTER --service-name $PREFIX-web --query 'taskArns[0]' --output text)
aws ecs execute-command --cluster $CLUSTER --task "$TASK" --container web --interactive --command "/bin/sh"
```

**Reach the database:**

- With `client-vpn` in the stack: connect to the VPN, then connect to `database.address` on 5432/3306 with TLS.
- Without a VPN: ECS Exec into a service container and use a client inside it.
- Credentials: `aws secretsmanager get-secret-value --secret-id <database.secret_arn>`.

---

## 3. Deployments

### 3.1 Normal deploy

- **CI-managed services** (`github_repository` set): merge to `main`; the workflow builds `<repo>:<sha>`
  and deploys it. The ECS circuit breaker rolls back automatically if the new tasks never become healthy.
- **Terraform-managed services**: change `image` (or push a new `:latest` and force a new deployment), then
  `terraform apply`.

### 3.2 Manual rollback

```bash
# list recent revisions of the service's task definition family
aws ecs list-task-definitions --family-prefix $PREFIX-web --sort DESC --max-items 5

aws ecs update-service --cluster $CLUSTER --service $PREFIX-web \
  --task-definition $PREFIX-web:<PREVIOUS_REVISION> --force-new-deployment

aws ecs wait services-stable --cluster $CLUSTER --services $PREFIX-web
```

Confirm the target group shows healthy targets before closing the incident. For Terraform-managed
services, also revert the change in code; otherwise the next `apply` redeploys it.

### 3.3 Database migrations

- Use **expand-contract** for breaking schema changes: add, backfill, switch reads, then remove in a later release.
- Take a manual snapshot first:
  `aws rds create-db-snapshot --db-instance-identifier $PREFIX-db --db-snapshot-identifier $PREFIX-pre-migration-$(date +%Y%m%d%H%M)`
- Do not roll back application code past a migration without a plan for the data written since.

---

## 4. Restore

### 4.1 RDS point-in-time restore (drill quarterly, and before go-live)

1. Pick the target time (for a drill, "latest restorable time":
   `aws rds describe-db-instances --db-instance-identifier $PREFIX-db --query 'DBInstances[0].LatestRestorableTime'`).
2. Restore to a **new** instance in the same subnet group and security group:
   ```bash
   aws rds restore-db-instance-to-point-in-time \
     --source-db-instance-identifier $PREFIX-db \
     --target-db-instance-identifier $PREFIX-db-restore \
     --use-latest-restorable-time \
     --db-subnet-group-name $PREFIX-db \
     --vpc-security-group-ids <database security group> \
     --no-publicly-accessible
   aws rds wait db-instance-available --db-instance-identifier $PREFIX-db-restore
   ```
3. Run smoke queries against the restored instance.
4. Record **RTO** (start of step 2 to queries passing) and **RPO** (data age at the restore point).
5. Delete the drill instance:
   `aws rds delete-db-instance --db-instance-identifier $PREFIX-db-restore --skip-final-snapshot`.

**Real recovery:** after validating the restored instance, point services at it with a temporary
`environment = { DB_HOST = "<restored address>" }` override and `terraform apply`. Then plan the cut-back into the
Terraform-managed instance, or `terraform import` the restored one in a change window.

### 4.2 EFS or RDS from AWS Backup (`production` / `regulated`)

```bash
aws backup list-recovery-points-by-backup-vault --backup-vault-name $PREFIX-vault \
  --query 'RecoveryPoints[].{arn:RecoveryPointArn,resource:ResourceArn,created:CreationDate}' --output table
```

Start the restore from the console (AWS Backup > Vaults > `$PREFIX-vault` > recovery point > Restore), using
role `$PREFIX-backup`. EFS restores into a new directory or file system, so the original data is untouched.

### 4.3 S3 objects

App, config and CloudTrail buckets are versioned. Restore an object by copying a previous version over the
current one (`aws s3api list-object-versions`, then `aws s3api copy-object` with `versionId`).

---

## 5. Data tier events

| Event | Expected behaviour | Action |
|:------|:-------------------|:-------|
| RDS Multi-AZ failover | 1-2 minutes of connection errors, same endpoint | Apps must reconnect; verify the `rds-cpu` alarm returns to OK |
| RDS single-AZ instance failure (`starter`) | Outage until AWS recovers the host or you restore | Section 4.1 |
| Redis primary failure (2+ nodes) | Replica promoted automatically, same primary endpoint | Check `redis-cpu`/`redis-memory` alarms |
| Redis node failure (1 node, `starter`) | Cache empty; sessions held only in Redis are lost | Apps must treat Redis as a cache; keep durable state in the database |
| `rds-storage` alarm | Storage autoscaling grows up to `rds_max_storage_gb` | If at the ceiling, raise `overrides.rds_max_storage_gb` and apply |

---

## 6. Secrets

| Secret | Rotate |
|:-------|:-------|
| RDS master password | `aws secretsmanager rotate-secret --secret-id <database.secret_arn>`. Running tasks keep the old value until restarted; force a new deployment of each service afterwards |
| Redis AUTH token | `terraform apply -replace='module.platform.module.redis[0].random_password.auth'`, then force a new deployment of each service. Test in non-production first |
| App secrets you reference in `services.*.secrets` | Rotate in Secrets Manager / SSM, then force a new deployment |

Force a new deployment: `aws ecs update-service --cluster $CLUSTER --service <service> --force-new-deployment`.

---

## 7. Connectivity

| Problem | Check |
|:--------|:------|
| Site-to-site tunnel down | VPC console > Site-to-Site VPN > Tunnel details. Both tunnels must be configured on the customer router (download the config for your device). Confirm the router's public IP equals `vpn.customer_gateway_ip` and IKEv2 + AES/SHA-2 are allowed |
| Routes missing on-prem to VPC | With BGP, check the router advertises its prefixes. With `static_routes`, the list must include the on-prem CIDRs |
| Client VPN users connect but reach nothing | They are authorized for the VPC CIDR only; the target's security group must allow the Client VPN group (the data tier already does) |
| Export a Client VPN profile | `aws ec2 export-client-vpn-client-configuration --client-vpn-endpoint-id <id> --output text > $PREFIX.ovpn` |
| Transit Gateway traffic not flowing | Attachment state `available`; route in the private route tables (`transit_gateway.routes`); return route on the other side |

---

## 8. Alerts and security findings

### 8.1 Test alert delivery

```bash
aws cloudwatch set-alarm-state --alarm-name $PREFIX-alb-5xx --state-value ALARM --state-reason "delivery test"
```

The email should arrive within a minute; the alarm returns to OK on its next evaluation.

### 8.2 Responding

| Alert | First steps |
|:------|:------------|
| `*-no-healthy-targets` | `aws ecs describe-services` events; the service's log group; the health check path; whether a deploy just ran (roll back, section 3.2) |
| `alb-5xx` / `targets-5xx` | ELB 5xx usually means no healthy targets or timeouts; target 5xx means application errors. Check the logs |
| `cis-root-account-usage` | Treat as an incident until the root user activity is explained. Check CloudTrail for the event |
| `cis-console-signin-without-mfa` | Identify the IAM user; enforce MFA or remove console access |
| `cis-cloudtrail-config-changes`, `cis-kms-key-disable-or-delete` | Confirm the change was planned; if not, restore the setting and investigate who made the call |
| `cis-iam-policy-changes`, `cis-security-group-changes` | Compare against recent Terraform applies; unexpected changes mean drift or compromise |
| GuardDuty high-severity finding | Follow the finding's remediation guidance; isolate the affected task or role (stop the task, revoke role sessions) |
| Inspector critical CVE in an image | Rebuild the image on a patched base and redeploy |

---

## 9. Incident response

Fill these in for your team and keep them current:

| Item | Value |
|:-----|:------|
| On-call owner (primary / secondary) | |
| Escalation path | |
| Incident channel | |
| Severity levels | P1: customer-facing outage or data at risk · P2: degraded or partial outage · P3: no customer impact |
| Post-incident review | Within 5 working days for P1/P2: timeline, impact, root cause, action items with owners |

---

## 10. Terraform hygiene

- State in S3 with versioning, encryption and `use_lockfile = true`. One state key per environment.
- Run changes through pull requests; CI must be green. Apply from CI or a single trusted machine.
- Never edit module-managed resources in the console. If you must during an incident, record the change and
  reconcile it in code afterwards (`terraform plan` shows the drift).
- Pin the module (`version = "X.Y.Z"` from the Registry, or `?ref=vX.Y.Z` for git sources) and upgrade one environment at a time, non-production first.
