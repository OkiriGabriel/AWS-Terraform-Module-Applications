# boiler-plate AWS Infrastructure Documentation
**Enhanced Version with CI/CD, DR, and Operational Excellence**

Primary Region: **us-east-1** (N. Virginia)  
Development Firm: Todhrisp Consulting  
Version: 2.1 | May 2026 | Confidential

## 1. Architecture Overview

### 1.0 Region strategy (us-east-1)

All Terraform, AMIs, AZs, ECR, CloudWatch logs, and runbooks use **us-east-1** only. Do not mix region codes in SLAs, security appendices, or environment variables.

| Factor | Rationale |
|--------|-----------|
| Cost | Broad service availability and competitive pricing for lean launch |
| Operations | Single region reduces provisioning and incident confusion |
| DR | S3 replication to **eu-central-1** for backup buckets (see `backup_dr.tf`) |
| Latency | UK/EU users served via Cloudflare CDN; API origin latency acceptable at launch |

For UK-specific latency later, evaluate **eu-west-2** (London) as a deliberate migration—not a mixed-region deployment.

### 1.1 Traffic Flow
**Production**: Browser → Cloudflare CDN/WAF → ALB (public subnets) → ECS Fargate (private subnets) → RDS MySQL & ElastiCache Redis (private subnets)  
**Development**: Browser → Cloudflare CDN/WAF → EC2 instances (public subnets) → Local MySQL/Redis

### 1.2 Service Inventory
| Service | Purpose | Environment | Scaling Model |
|---------|---------|-------------|---------------|
| Amazon ECS Fargate | Production containers (Frontend: WordPress/WooCommerce, Backend API, Admin Dashboard) | Prod | Auto-scaling 1-12 tasks |
| Amazon EC2 | Development server (Frontend: t3.medium) | Dev | Single instance |
| Application Load Balancer | Multi-service routing with path-based rules | Prod | Multi-AZ, auto-scaling |
| Amazon RDS MySQL | Primary database with automated backups | Prod | Single-AZ (upgradable to Multi-AZ) |
| Amazon ElastiCache Redis | Session cache, rate limiting, WordPress object cache | Prod | Single node (upgradable to cluster) |
| Amazon ECR | Container image registry with automated builds | Prod | Unlimited storage |
| Amazon S3 | Static assets, media files, backups, environment configs | All | Multi-AZ by default |
| Amazon EC2 (Monitoring) | Prometheus, Grafana, Blackbox, SonarQube | Prod | Single instance (t2.small) |
| AWS Secrets Manager | Environment variables and credentials | All | Multi-AZ by default |
| Amazon SES | Transactional email | Prod | Regional service |
| Amazon CloudWatch | Logs, metrics, and monitoring | All | Regional service |
| Amazon EFS | Shared WordPress files, plugins, uploads | Prod | Multi-AZ file system |

## 2. Network Architecture

### 2.1 VPC Configuration
| Component | CIDR Range | Availability Zone | Purpose |
|-----------|------------|-------------------|---------|
| VPC | 10.0.0.0/16 | us-east-1 | Main network (65,536 IP addresses) |

### 2.2 Subnet Configuration
| Subnet Name | CIDR Range | Availability Zone | Type | Purpose |
|-------------|------------|-------------------|------|---------|
| boiler-plate-public-a | 10.0.1.0/24 | us-east-1a | Public | NAT Gateway, ALB |
| boiler-plate-public-b | 10.0.2.0/24 | us-east-1b | Public | NAT Gateway, ALB (HA) |
| boiler-plate-app-private-a | 10.0.10.0/24 | us-east-1a | Private | ECS Fargate tasks, Monitoring server |
| boiler-plate-app-private-b | 10.0.20.0/24 | us-east-1b | Private | ECS Fargate tasks (HA) |

### 2.3 Security & Access
- **Development**: EC2 instances in public subnets with Cloudflare protection
- **Production**: All applications in private subnets, internet access via NAT Gateway
- **Database**: Private subnets only, accessible from application subnets
- **Monitoring**: Private subnet with ALB access for Grafana and SonarQube

## 3. WordPress/WooCommerce Scaling Model

### 3.1 ECS Fargate Architecture
```
Frontend Service (WordPress/WooCommerce):
├── ECS Tasks: 1-4 (auto-scaling based on CPU/memory)
├── Shared Storage: Amazon EFS for wp-content, plugins, uploads
├── Session Storage: ElastiCache Redis
├── Database: RDS MySQL (shared connection pooling)
└── Media Delivery: S3 + CloudFront + Cloudflare CDN
```

### 3.2 WordPress Scaling Components
| Component | Solution | Scaling Method |
|-----------|----------|----------------|
| **File Storage** | Amazon EFS | Multi-AZ, elastic scaling |
| **Media Files** | S3 + CDN | Pre-signed URLs, automatic scaling |
| **Session Management** | ElastiCache Redis | In-memory sessions; single node at launch (replica at revenue milestone) |
| **Database** | RDS MySQL | Connection pooling, read replicas (future) |
| **Plugin Updates** | EFS shared mount | Zero-downtime rolling updates |
| **Cache Strategy** | Redis + WordPress Object Cache | Multi-layer caching |

### 3.3 WordPress Container Configuration
```dockerfile
# WordPress ECS Task includes:
- WordPress core + WooCommerce
- Redis Object Cache plugin
- EFS mount for wp-content
- S3 media offloading plugin
- Database connection pooling
- Health check endpoint (/wp-admin/admin-ajax.php)
```

### 3.4 Fargate capacity

- Critical services use **on-demand Fargate** with `min_capacity` ≥ 1 (no Spot-only baseline).
- Configure ALB health checks, graceful shutdown, and stable sessions/carts across task replacement (EFS + Redis + DB).

## 4. Geolocation & Region-Aware Logic

### 4.1 City-Level Detection Architecture
```
Cloudflare → Geographic Detection:
├── City-level IP geolocation
├── Vendor availability mapping (Redis cache)
├── Courier service zones (Database lookup)
└── Region override cookies/headers
```

### 4.2 Implementation Components
| Component | Technology | Purpose |
|-----------|------------|---------|
| **IP Geolocation** | Cloudflare + MaxMind | City-level accuracy |
| **Vendor Mapping** | Redis + MySQL | Real-time vendor availability |
| **Courier Logic** | Backend API + Redis | Service area calculation |
| **Region Override** | Frontend + Cookies | User preference handling |

### 4.3 Data Flow
1. **User Request** → Cloudflare detects city/region
2. **Backend API** → Queries available vendors by location
3. **Redis Cache** → Stores vendor availability (5min TTL)
4. **Frontend** → Displays location-specific content
5. **Override Logic** → Users can change location manually

## 5. CI/CD Pipeline

### 5.1 Build & Deploy Pipeline
```mermaid
Developer Push → GitHub → GitHub Actions:
├── Code Quality: SonarQube scan
├── Security Scan: Container vulnerability check
├── Build: Docker image creation
├── Registry: Push to ECR
├── Deploy Dev: ECS service update (dev environment)
├── Integration Tests: Automated API/UI testing
├── Deploy Prod: ECS blue/green deployment
└── Rollback: Automated on failure detection
```

### 5.2 Pipeline Components
| Stage | Tool | Duration | Failure Action |
|-------|------|----------|----------------|
| **Code Quality** | SonarQube | 2-5 min | Block deployment |
| **Security Scan** | AWS ECR scan | 1-3 min | Block on HIGH/CRITICAL |
| **Build** | Docker + GitHub Actions | 3-8 min | Retry once, then fail |
| **Deploy Dev** | ECS rolling update | 2-5 min | Auto-rollback |
| **Integration Tests** | Playwright + Newman | 5-15 min | Block prod deployment |
| **Deploy Prod** | ECS blue/green | 10-20 min | Auto-rollback on health check fail |

### 5.3 Rollback Strategy
- **Automatic**: Health check failures trigger immediate rollback
- **Manual**: One-click rollback via AWS Console/CLI
- **Database**: Schema migrations require manual review
- **Assets**: S3 versioning enables quick asset rollback

### 5.4 Database migration safety
- Use **expand–contract** patterns for breaking changes
- Snapshot RDS before production migrations; rehearse in staging
- Prepare rollback scripts where safe; never assume app-only rollback is safe for orders/payments
- See `OPERATIONS_RUNBOOK.md` for restore tests and ECS rollback commands

## 6. Disaster Recovery & High Availability

### 6.1 DR Strategy Overview
| Component | DR Method | RTO Target | RPO Target |
|-----------|-----------|------------|------------|
| **Application** | Multi-AZ ECS | 5 minutes | 0 (stateless) |
| **Database** | Automated backups + snapshots | 30 minutes | 15 minutes |
| **Redis Cache** | Rebuild from database | 10 minutes | 0 (cache) |
| **File Storage** | EFS automatic backups | 15 minutes | 4 hours |
| **Static Assets** | S3 cross-region replication | 5 minutes | 15 minutes |

### 6.2 Multi-AZ Configuration
```
Production Setup (High Availability):
├── ALB: 2 AZs (us-east-1a, us-east-1b)
├── ECS: Tasks distributed across 2 AZs
├── RDS: Single-AZ (cost), upgradable to Multi-AZ
├── Redis: Single node (cost), upgradable to cluster
├── EFS: Multi-AZ by default
└── S3: Multi-AZ by default
```

### 6.3 DR Procedures
1. **Database Recovery**: Restore from automated backup (point-in-time)
2. **Application Recovery**: ECS auto-scaling handles instance failures
3. **Cache Recovery**: Redis rebuilds from database queries
4. **File Recovery**: EFS backup restore (managed service)
5. **Full Region Failover**: Manual process with secondary region setup

### 6.4 Launch risk acceptance (Single-AZ)

| Component | Launch config | Mitigation before go-live |
|-----------|---------------|---------------------------|
| RDS | Single-AZ | Documented restore test with measured RTO/RPO |
| Redis | Single node | Documented cache-miss and session behaviour (`OPERATIONS_RUNBOOK.md` §3) |
| Monitoring | Single EC2 ASG | Independent CloudWatch/SNS alarms (`monitoring_alerts.tf`) |

### 6.5 Redis failure summary

On Redis outage: object cache misses reload from MySQL; users may need to re-login; rate limits and locks use documented fallbacks. Full detail in `OPERATIONS_RUNBOOK.md`.

## 7. Logging & Observability

### 7.1 Logging Architecture
```
Application Logs → CloudWatch → Prometheus → Grafana:
├── ECS Container Logs: /ecs/{environment}-{service}
├── ALB Access Logs: S3 bucket with analysis
├── RDS Logs: CloudWatch Logs integration
├── Application Metrics: Custom metrics via CloudWatch
└── Error Tracking: CloudWatch Insights + Custom dashboards
```

### 7.2 Monitoring Stack
| Component | Tool | Data Retention | Alerting |
|-----------|------|----------------|----------|
| **Metrics Collection** | Prometheus | 30 days | Yes |
| **Visualization** | Grafana | Persistent | Yes |
| **Uptime Monitoring** | Blackbox Exporter | 30 days | Yes |
| **Log Aggregation** | CloudWatch Logs | 30 days | Yes |
| **Distributed Tracing** | CloudWatch X-Ray | 30 days | No |
| **Error Tracking** | CloudWatch Insights | 30 days | Yes |

### 7.3 Alert Configuration
| Alert Type | Trigger | Notification | Recipients |
|------------|---------|-------------|------------|
| **Service Downtime** | Service unavailable > 2min | Slack + Email | Operations team |
| **High Error Rate** | Error rate > 5% | Slack | Development team |
| **Resource Exhaustion** | CPU/Memory > 80% | Email | DevOps team |
| **Database Issues** | Connection failures | Slack + Email | Database team |
| **Monitoring host down** | ASG in-service < 1 | SNS (CloudWatch) | Operations team |
| **ALB unhealthy targets** | UnHealthyHostCount > 0 | SNS (CloudWatch) | Operations team |

### 7.4 Monitoring SPOF mitigation

The Prometheus/Grafana EC2 stack is a single point of failure. **CloudWatch metric alarms** (RDS, ALB, ECS, Redis, monitoring ASG) publish to SNS independently so alerting continues if the monitoring server is down. Subscribe `${environment}-dr-alerts` to on-call channels before launch.

## 8. Security Enhancements

### 8.1 Cloudflare WAF Configuration
| Protection Type | Rules | Action |
|----------------|--------|---------|
| **Rate Limiting** | 100 req/min per IP | Challenge/Block |
| **Bot Protection** | Machine learning detection | Challenge |
| **SQL Injection** | OWASP Core Rule Set | Block |
| **XSS Protection** | Script injection detection | Block |
| **API Security** | /api/* rate limiting | Block/Challenge |
| **Geoblocking** | Country-based restrictions | Block (configurable) |

### 8.2 Security Layers
```
Security Stack:
├── Cloudflare: DDoS, WAF, Bot protection
├── ALB: SSL termination, security groups
├── VPC: Private subnets, NACLs
├── ECS: Task-level security groups
├── RDS: Encryption at rest, VPC security
├── S3: Bucket policies, encryption
└── Secrets Manager: Credential rotation
```

## 9. Cost Optimization & Scaling Path

### 9.1 Development Environment
| Component | Monthly Cost | Scaling Trigger |
|-----------|-------------|-----------------|
| EC2 Frontend (t3.medium) | $35 | Manual scaling |
| Supporting services | $7 | N/A |
| **Total Development** | **$42** | N/A |

### 9.2 Production Environment
| Component | Monthly Cost | Scaling Trigger |
|-----------|-------------|-----------------|
| ECS Fargate (3 services) | $12 | Auto-scaling |
| Application Load Balancer | $18 | N/A |
| RDS MySQL (db.t3.micro) | $15 | $500/month revenue |
| ElastiCache Redis | $13 | $1000/month revenue |
| Monitoring Server (t2.small) | $18 | Manual scaling |
| NAT Gateway | $16 | $500/month revenue (add 2nd) |
| Supporting services | $8 | N/A |
| **Total Production** | **$100** | Revenue-based |

### 9.3 Scaling Milestones
| Revenue Milestone | Infrastructure Change | Additional Cost |
|-------------------|----------------------|-----------------|
| **$500/month** | Add 2nd NAT Gateway for HA | +$16/month |
| **$1000/month** | Enable RDS Multi-AZ | +$15/month |
| **$1500/month** | Add Redis replica | +$13/month |
| **$2000/month** | Enable detailed monitoring | +$5/month |
| **$5000/month** | Migrate to larger instances | +$50/month |

## 10. Operational Excellence

### 10.1 Maintenance Windows
- **Database Maintenance**: Sundays 2:00-4:00 AM UTC
- **Security Updates**: Rolling updates (zero downtime)
- **ECS Task Updates**: Blue/green deployment
- **Cache Maintenance**: Automated, transparent to users

### 10.2 Backup Strategy
| Component | Backup Frequency | Retention | Recovery Time |
|-----------|------------------|-----------|---------------|
| **RDS MySQL** | Automated daily + snapshots | 7 days | 15-30 minutes |
| **EFS WordPress Files** | Daily automated | 30 days | 15 minutes |
| **S3 Static Assets** | Versioning enabled | 90 days | Immediate |
| **ECS Configuration** | Infrastructure as Code | Version controlled | 10 minutes |

### 10.3 Related documents

- `OPERATIONS_RUNBOOK.md` — restore tests, Redis failure, rollback, CI checklist
- `monitoring_alerts.tf` — independent CloudWatch/SNS alarms
- `.github/workflows/terraform-ci.yml` — Terraform validate and region consistency check

This documentation is aligned with **us-east-1** Terraform and addresses Technical Assurance feedback on consistency, reliability, and operational proof.