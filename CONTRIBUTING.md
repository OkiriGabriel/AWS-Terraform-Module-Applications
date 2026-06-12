# Contributing to Gabriel AWS Infrastructure Boilerplate

Thank you for your interest in contributing to this project! We welcome contributions from the community and appreciate your help in making this boilerplate better.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for everyone.

## How to Contribute

### Reporting Issues

- **Bug Reports**: Use GitHub Issues to report bugs. Include:
  - Clear description of the problem
  - Steps to reproduce
  - Expected vs actual behavior
  - Terraform version and provider versions
  - Relevant configuration snippets

- **Feature Requests**: Propose new features or modules through GitHub Issues. Explain:
  - The use case
  - How it benefits users
  - Potential implementation approach

### Pull Requests

1. **Fork the Repository**
   ```bash
   git clone https://github.com/yourusername/gabriel-aws-infrastructure.git
   cd gabriel-aws-infrastructure
   ```

2. **Create a Feature Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make Your Changes**
   - Follow the existing code style
   - Add tests if applicable
   - Update documentation

4. **Test Your Changes**
   ```bash
   terraform fmt -recursive
   terraform validate
   terraform plan
   ```

5. **Commit Your Changes**
   ```bash
   git add .
   git commit -m "feat: add amazing new feature"
   ```

6. **Push to Your Fork**
   ```bash
   git push origin feature/your-feature-name
   ```

7. **Open a Pull Request**
   - Provide a clear title and description
   - Reference any related issues
   - Explain the changes and their purpose

## Contribution Guidelines

### Module Development

When creating new modules:

1. **Structure**
   ```
   modules/your-module/
   ├── main.tf          # Main resource definitions
   ├── variables.tf     # Input variables
   ├── outputs.tf       # Output values
   └── README.md        # Module documentation
   ```

2. **Naming Conventions**
   - Use lowercase with underscores for resources: `aws_instance.web_server`
   - Use descriptive names: `application_load_balancer` not `alb1`
   - Prefix resource names with module purpose

3. **Variables**
   - Provide clear descriptions
   - Set sensible defaults where appropriate
   - Use validation blocks for constraints
   - Mark sensitive variables as `sensitive = true`

4. **Outputs**
   - Export all useful resource attributes
   - Provide clear descriptions
   - Mark sensitive outputs as `sensitive = true`

5. **Documentation**
   - Create comprehensive README.md
   - Include usage examples
   - Document all inputs and outputs
   - Explain common use cases
   - Add troubleshooting tips

### Code Style

- **Formatting**: Use `terraform fmt` for consistent formatting
- **Comments**: Add comments for complex logic
- **Variables**: Group related variables together
- **Resources**: Use dynamic blocks when appropriate
- **Data Sources**: Fetch required information rather than hardcoding
- **Dependencies**: Use `depends_on` only when necessary

### Example Module Template

```hcl
# modules/example/main.tf
resource "aws_example_resource" "main" {
  name        = var.name
  description = var.description
  
  enabled = var.enabled
  
  dynamic "configuration" {
    for_each = var.configurations
    content {
      key   = configuration.value.key
      value = configuration.value.value
    }
  }
  
  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}

# modules/example/variables.tf
variable "name" {
  description = "Name of the resource"
  type        = string
}

variable "description" {
  description = "Description of the resource"
  type        = string
  default     = "Managed by Terraform"
}

variable "enabled" {
  description = "Enable the resource"
  type        = bool
  default     = true
}

variable "configurations" {
  description = "Map of configurations"
  type = map(object({
    key   = string
    value = string
  }))
  default = {}
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

# modules/example/outputs.tf
output "id" {
  description = "The ID of the resource"
  value       = aws_example_resource.main.id
}

output "arn" {
  description = "The ARN of the resource"
  value       = aws_example_resource.main.arn
}
```

### Testing

1. **Validation**
   ```bash
   terraform validate
   ```

2. **Formatting**
   ```bash
   terraform fmt -check -recursive
   ```

3. **Security Scanning** (recommended)
   ```bash
   tfsec .
   checkov -d .
   ```

4. **Plan Testing**
   ```bash
   terraform plan
   ```

### Documentation Standards

- **README.md**: Each module must have comprehensive documentation
- **Examples**: Provide real-world usage examples
- **Architecture Diagrams**: Include ASCII art or diagrams where helpful
- **Prerequisites**: List any requirements or dependencies
- **Inputs Table**: Document all variables with types and defaults
- **Outputs Table**: Document all outputs
- **Best Practices**: Include recommendations for using the module

### Commit Message Format

Follow conventional commits:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting)
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

**Examples:**
```
feat(eks): add support for Kubernetes 1.29

- Added support for EKS 1.29
- Updated default node AMI
- Added new addon versions

Closes #123
```

```
fix(guardduty): correct SNS topic policy

The previous policy didn't allow EventBridge to publish.
Updated the principal to include events.amazonaws.com.

Fixes #456
```

## Review Process

1. **Automated Checks**: Pull requests trigger automated checks
2. **Code Review**: Maintainers review code quality and design
3. **Testing**: Changes are tested in isolated environments
4. **Documentation**: Ensure docs are updated
5. **Approval**: At least one maintainer approval required
6. **Merge**: Squash and merge to main branch

## Development Setup

### Prerequisites

- Terraform >= 1.0.0
- AWS CLI configured
- Git
- Text editor or IDE

### Local Testing

1. Create a test directory:
   ```bash
   mkdir test
   cd test
   ```

2. Create a minimal test configuration:
   ```hcl
   module "test" {
     source = "../modules/your-module"
     
     # Minimal required variables
     name = "test"
   }
   ```

3. Initialize and test:
   ```bash
   terraform init
   terraform plan
   ```

## Getting Help

- **Questions**: Open a GitHub Discussion
- **Issues**: Check existing issues before creating new ones
- **Slack/Discord**: Join our community (if available)
- **Documentation**: Check the wiki and module READMEs

## Recognition

Contributors will be recognized in:
- README.md contributors section
- Release notes
- Project documentation

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to making this project better! 🚀
