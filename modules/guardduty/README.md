# GuardDuty Module

This module enables and configures AWS GuardDuty for intelligent threat detection and continuous security monitoring.

## Features

- GuardDuty detector with customizable protection options
- S3 protection monitoring
- Kubernetes audit logs monitoring
- Malware protection for EC2 instances
- SNS notifications for security findings
- S3 export of findings for long-term storage
- CloudWatch Logs integration
- Auto-archiving of low-severity findings
- Custom threat intelligence integration
- Trusted IP list support
- KMS encryption for findings

## Usage

```hcl
module "guardduty" {
  source = "./modules/guardduty"

  name_prefix = "my-org"
  
  enable                      = true
  enable_s3_protection        = true
  enable_kubernetes_protection = true
  enable_malware_protection   = true
  
  enable_notifications    = true
  notification_emails     = ["security@example.com", "ops@example.com"]
  minimum_severity_level  = 4.0
  
  enable_findings_export    = true
  enable_cloudwatch_logs    = true
  log_retention_days        = 90
  
  auto_archive_low_severity = false
  
  tags = {
    Environment = "production"
    SecurityTool = "guardduty"
  }
}
```

## Finding Severity Levels

GuardDuty assigns a severity level to each finding:

- **High (7.0-8.9)**: Immediate action recommended
- **Medium (4.0-6.9)**: Investigation recommended
- **Low (0.1-3.9)**: Information only, may be expected behavior

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| enable | Enable GuardDuty detector | bool | true | no |
| name_prefix | Prefix for resource names | string | "guardduty" | no |
| finding_publishing_frequency | Frequency of notifications | string | "FIFTEEN_MINUTES" | no |
| enable_s3_protection | Enable S3 protection | bool | true | no |
| enable_kubernetes_protection | Enable K8s protection | bool | true | no |
| enable_malware_protection | Enable malware protection | bool | true | no |
| enable_notifications | Enable SNS notifications | bool | true | no |
| notification_emails | Email addresses for alerts | list(string) | [] | no |
| minimum_severity_level | Min severity for notifications | number | 4.0 | no |
| enable_findings_export | Export findings to S3 | bool | true | no |
| tags | Tags to apply | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| detector_id | GuardDuty detector ID |
| detector_arn | GuardDuty detector ARN |
| sns_topic_arn | SNS topic ARN for findings |
| findings_bucket_name | S3 bucket name for findings |
| kms_key_id | KMS key ID for encryption |

## Common Finding Types

- **UnauthorizedAccess**: Unusual API calls or unauthorized access attempts
- **Recon**: Port scanning, unusual network traffic patterns
- **Trojan**: Malware or trojan behavior detected
- **Backdoor**: Backdoor communication detected
- **CryptoCurrency**: Cryptocurrency mining activity
- **Persistence**: Attempts to maintain access

## Best Practices

1. Set up email notifications for your security team
2. Enable all protection types for comprehensive coverage
3. Export findings to S3 for compliance and auditing
4. Integrate with SIEM or security orchestration tools
5. Review findings regularly and adjust severity thresholds
6. Use trusted IP lists for known safe sources
7. Enable auto-archiving for low-severity findings in non-critical environments

## Integration with Other Services

GuardDuty works well with:
- AWS Security Hub (centralized security findings)
- Amazon Detective (investigation and analysis)
- AWS Systems Manager (automated response)
- Lambda (custom remediation actions)

## License

MIT
