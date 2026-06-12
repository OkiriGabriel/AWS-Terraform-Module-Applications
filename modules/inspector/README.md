# AWS Inspector Module

This module enables and configures AWS Inspector for automated security assessment and vulnerability scanning.

## Features

- Automated vulnerability scanning for EC2, ECR, and Lambda
- Continuous scanning with real-time notifications
- SNS notifications for security findings
- CloudWatch Logs integration
- S3 export for assessment reports
- Severity-based filtering
- CloudWatch alarms for high-severity findings
- Support for automated remediation
- Multi-account support with delegated administration

## What Inspector Scans

### EC2 Instances
- Operating system vulnerabilities (CVEs)
- Network reachability issues
- Missing security patches
- Software vulnerabilities in installed packages

### ECR (Container Images)
- Container image vulnerabilities
- Package vulnerabilities in container layers
- CVE detection in container software

### Lambda Functions
- Lambda function code vulnerabilities
- Dependency vulnerabilities
- Runtime vulnerabilities

## Usage

```hcl
module "inspector" {
  source = "./modules/inspector"

  name_prefix = "my-org"
  
  resource_types = ["EC2", "ECR", "LAMBDA"]
  
  enable_notifications = true
  notification_emails  = ["security@example.com"]
  severity_filter      = ["CRITICAL", "HIGH"]
  
  enable_cloudwatch_logs = true
  log_retention_days     = 90
  
  enable_report_export   = true
  report_retention_days  = 365
  
  enable_alarms            = true
  high_severity_threshold  = 1
  
  tags = {
    Environment  = "production"
    SecurityTool = "inspector"
  }
}
```

## Severity Levels

Inspector assigns severity levels to findings:

- **CRITICAL**: Immediate action required
- **HIGH**: Prompt attention needed
- **MEDIUM**: Should be addressed soon
- **LOW**: Address as time permits
- **INFORMATIONAL**: For awareness only

## Common Vulnerability Types

### Network Reachability
- Services exposed to the internet
- Unrestricted access from 0.0.0.0/0
- Unnecessary open ports

### Package Vulnerabilities
- CVEs in installed packages
- Outdated software versions
- Known exploitable vulnerabilities

### Container Vulnerabilities
- Vulnerabilities in base images
- Vulnerabilities in application dependencies
- Misconfigured container settings

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name_prefix | Prefix for resource names | string | "inspector" | no |
| resource_types | Types of resources to scan | list(string) | ["EC2", "ECR", "LAMBDA"] | no |
| enable_notifications | Enable SNS notifications | bool | true | no |
| notification_emails | Email addresses for alerts | list(string) | [] | no |
| severity_filter | Filter by severity | list(string) | ["CRITICAL", "HIGH"] | no |
| enable_cloudwatch_logs | Send to CloudWatch Logs | bool | true | no |
| enable_report_export | Export reports to S3 | bool | true | no |
| tags | Tags to apply | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| enabler_id | Inspector enabler ID |
| sns_topic_arn | SNS topic ARN for findings |
| reports_bucket_name | S3 bucket for reports |
| cloudwatch_log_group_name | CloudWatch log group name |
| enabled_resource_types | List of enabled resource types |

## Best Practices

1. **Enable All Resource Types**: Scan EC2, ECR, and Lambda for complete coverage
2. **Set Up Notifications**: Configure email alerts for critical findings
3. **Regular Review**: Review findings weekly and prioritize remediation
4. **Automated Remediation**: Use Systems Manager or Lambda for automated patching
5. **Compliance**: Export reports for compliance auditing
6. **Suppression Rules**: Suppress false positives after investigation
7. **Multi-Account**: Use delegated admin for organization-wide scanning

## Automated Remediation

Inspector can trigger automated remediation:

```hcl
module "inspector" {
  # ... other configuration ...
  
  enable_automated_remediation = true
}
```

This creates an IAM role that can be used with:
- AWS Systems Manager for patching
- Lambda functions for custom remediation
- Step Functions for complex workflows

## Integration with Other Services

Inspector works well with:
- **AWS Security Hub**: Centralized security findings
- **AWS Systems Manager**: Patch management
- **AWS Config**: Compliance tracking
- **Amazon EventBridge**: Custom automation
- **AWS Lambda**: Custom remediation logic

## Multi-Account Setup

For AWS Organizations:

```hcl
# In management account
module "inspector_admin" {
  source = "./modules/inspector"
  
  delegated_admin_account_id = "123456789012"
  
  # ... other configuration ...
}
```

## Viewing Findings

Access Inspector findings:

1. **AWS Console**: AWS Inspector → Findings
2. **AWS CLI**: `aws inspector2 list-findings`
3. **CloudWatch Logs**: Check configured log group
4. **S3 Reports**: Download from reports bucket

## Cost Considerations

Inspector pricing is based on:
- Number of EC2 instances scanned
- Number of container images scanned
- Number of Lambda functions scanned

Scanning is continuous with monthly charges per resource.

## License

MIT
