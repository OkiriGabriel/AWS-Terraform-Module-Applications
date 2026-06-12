# Branching Strategy

This document outlines the recommended Git branching strategy for managing infrastructure as code with Terraform.

## Overview

We use a **modified GitFlow** branching strategy optimized for infrastructure management, with environment-specific branches and feature branches for changes.

## Branch Structure

```
main (production)
├── staging
├── development
└── feature branches
    ├── feature/add-eks-module
    ├── feature/update-rds-config
    ├── fix/guardduty-permissions
    └── hotfix/security-group-rule
```

## Main Branches

### `main` - Production Environment

- **Purpose**: Reflects production infrastructure
- **Protection**: Highly protected, requires approvals
- **Deploys to**: Production AWS account/environment
- **Merges from**: `staging` branch only (after testing)
- **Direct commits**: Never allowed

**Branch Protection Rules:**
- Require pull request reviews (minimum 2 approvers)
- Require status checks to pass
- Require branches to be up to date
- Include administrators in restrictions
- Require signed commits (recommended)

### `staging` - Staging Environment

- **Purpose**: Pre-production testing environment
- **Protection**: Protected, requires approval
- **Deploys to**: Staging AWS account/environment
- **Merges from**: `development` branch and hotfixes
- **Direct commits**: Not allowed

**Branch Protection Rules:**
- Require pull request reviews (minimum 1 approver)
- Require status checks to pass
- Require branches to be up to date

### `development` - Development Environment

- **Purpose**: Integration and testing environment
- **Protection**: Moderate protection
- **Deploys to**: Development AWS account/environment
- **Merges from**: Feature branches
- **Direct commits**: Allowed for minor changes only

**Branch Protection Rules:**
- Require pull request reviews (optional for team members)
- Require status checks to pass

## Supporting Branches

### Feature Branches

For new features, modules, or enhancements.

**Naming Convention:**
```
feature/<short-description>
```

**Examples:**
- `feature/add-eks-cluster`
- `feature/guardduty-integration`
- `feature/vpc-peering-setup`
- `feature/transit-gateway-config`

**Workflow:**
1. Branch from: `development`
2. Merge back to: `development`
3. Lifetime: Until feature is complete and merged
4. Delete after: Merge is complete

**Commands:**
```bash
# Create feature branch
git checkout development
git pull origin development
git checkout -b feature/add-eks-cluster

# Work on feature
git add .
git commit -m "feat: add EKS cluster module"

# Push to remote
git push -u origin feature/add-eks-cluster

# Create PR to development
```

### Bugfix Branches

For fixing non-critical bugs in development or staging.

**Naming Convention:**
```
fix/<short-description>
```

**Examples:**
- `fix/rds-backup-window`
- `fix/security-group-ingress`
- `fix/s3-bucket-policy`

**Workflow:**
1. Branch from: `development` or `staging`
2. Merge back to: Same branch + upstream branches
3. Delete after: Merge is complete

### Hotfix Branches

For critical production fixes that can't wait for the normal release cycle.

**Naming Convention:**
```
hotfix/<short-description>
```

**Examples:**
- `hotfix/critical-security-vulnerability`
- `hotfix/production-outage`
- `hotfix/exposed-s3-bucket`

**Workflow:**
1. Branch from: `main` (production)
2. Merge to: `main`, `staging`, and `development` (all branches)
3. **Immediate deployment** after testing
4. Delete after: Merged to all branches

**Commands:**
```bash
# Create hotfix
git checkout main
git pull origin main
git checkout -b hotfix/critical-security-fix

# Fix the issue
git add .
git commit -m "hotfix: fix critical security vulnerability"

# Push and create PRs to all branches
git push -u origin hotfix/critical-security-fix
```

### Refactor Branches

For code refactoring without changing functionality.

**Naming Convention:**
```
refactor/<short-description>
```

**Examples:**
- `refactor/module-structure`
- `refactor/variable-naming`
- `refactor/consolidate-security-groups`

### Documentation Branches

For documentation-only changes.

**Naming Convention:**
```
docs/<short-description>
```

**Examples:**
- `docs/update-readme`
- `docs/add-module-examples`
- `docs/architecture-diagrams`

## Workflow

### Standard Feature Development

```
1. Create feature branch from development
   ↓
2. Develop and test locally
   ↓
3. Push to remote and create PR to development
   ↓
4. Code review and approval
   ↓
5. Merge to development → auto-deploy to dev environment
   ↓
6. Test in dev environment
   ↓
7. Create PR from development to staging
   ↓
8. Merge to staging → auto-deploy to staging environment
   ↓
9. Test in staging environment
   ↓
10. Create PR from staging to main
    ↓
11. Merge to main → auto-deploy to production (with manual approval)
```

### Hotfix Workflow

```
1. Create hotfix branch from main
   ↓
2. Fix the critical issue
   ↓
3. Test the fix
   ↓
4. Create PR to main (expedited review)
   ↓
5. Merge to main → deploy to production
   ↓
6. Cherry-pick or merge to staging and development
```

## Branch Naming Conventions

### Format
```
<type>/<short-description>
```

### Types
- `feature/` - New features or modules
- `fix/` - Bug fixes
- `hotfix/` - Critical production fixes
- `refactor/` - Code refactoring
- `docs/` - Documentation updates
- `test/` - Adding or updating tests
- `chore/` - Maintenance tasks

### Description Rules
- Use lowercase
- Use hyphens (not underscores or spaces)
- Keep it short but descriptive (max 50 chars)
- Use imperative mood

**Good Examples:**
- `feature/add-guardduty-module`
- `fix/rds-connection-timeout`
- `hotfix/s3-public-access`
- `refactor/security-groups`
- `docs/update-contributing-guide`

**Bad Examples:**
- `feature/AddGuardDutyModule` (use lowercase)
- `fix/fixing_the_rds_timeout_issue_that_was_reported` (too long)
- `update-docs` (missing type prefix)
- `stuff` (not descriptive)

## Commit Message Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation only
- `style:` - Formatting changes
- `refactor:` - Code refactoring
- `test:` - Adding tests
- `chore:` - Maintenance

### Examples

```bash
feat(eks): add EKS cluster module with managed node groups

- Added main.tf with cluster configuration
- Added variables.tf with all customization options
- Added outputs.tf with cluster details
- Includes support for multiple node groups

Closes #123
```

```bash
fix(guardduty): correct SNS topic policy for EventBridge

The SNS topic policy was missing the events.amazonaws.com principal,
preventing GuardDuty findings from being published to the topic.

Fixes #456
```

```bash
hotfix(security): remove public access from S3 bucket

BREAKING CHANGE: S3 bucket is now private only
```

## Pull Request Process

### 1. Create Pull Request

**Title Format:**
```
<type>: <short description>
```

**Description Template:**
```markdown
## Description
Brief description of the changes

## Type of Change
- [ ] New feature
- [ ] Bug fix
- [ ] Hotfix
- [ ] Refactor
- [ ] Documentation

## Testing
- [ ] terraform fmt
- [ ] terraform validate
- [ ] terraform plan (reviewed)
- [ ] Tested in dev environment
- [ ] Tested in staging (if applicable)

## Checklist
- [ ] Code follows style guidelines
- [ ] Documentation updated
- [ ] No sensitive data committed
- [ ] Variables documented
- [ ] Outputs documented

## Related Issues
Closes #123
```

### 2. Code Review

**Reviewers should check:**
- [ ] Terraform syntax and best practices
- [ ] Security implications
- [ ] Cost implications
- [ ] Naming conventions
- [ ] Documentation
- [ ] No hardcoded values
- [ ] Proper use of variables
- [ ] Outputs are useful
- [ ] Tags are consistent

### 3. Automated Checks

Run these checks automatically via CI/CD:
```bash
# Format check
terraform fmt -check -recursive

# Validation
terraform validate

# Security scanning
tfsec .
checkov -d .

# Plan (with cost estimation)
terraform plan -out=tfplan
infracost breakdown --path tfplan
```

### 4. Approval and Merge

- **Development**: 0-1 approvals required
- **Staging**: 1 approval required
- **Main (Production)**: 2 approvals required + manual deployment approval

**Merge Strategy:**
- Use **Squash and Merge** for feature branches (clean history)
- Use **Merge Commit** for environment promotions (preserve history)
- Use **Rebase and Merge** for documentation/small fixes (optional)

## Environment Mapping

| Branch | Environment | AWS Account | Auto-Deploy | Manual Approval |
|--------|------------|-------------|-------------|-----------------|
| `development` | Development | dev-account | Yes | No |
| `staging` | Staging | staging-account | Yes | No |
| `main` | Production | prod-account | No | Yes (required) |

## Terraform Workspaces

Use Terraform workspaces aligned with branches:

```bash
# Development branch → dev workspace
terraform workspace select dev

# Staging branch → staging workspace
terraform workspace select staging

# Main branch → prod workspace
terraform workspace select prod
```

## CI/CD Integration

### GitHub Actions Example

```yaml
# .github/workflows/terraform.yml
name: Terraform

on:
  pull_request:
    branches: [development, staging, main]
  push:
    branches: [development, staging, main]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
      
      - name: Terraform Format
        run: terraform fmt -check -recursive
      
      - name: Terraform Init
        run: terraform init
      
      - name: Terraform Validate
        run: terraform validate
      
      - name: Terraform Plan
        run: terraform plan -no-color
        
      - name: Security Scan
        run: |
          docker run --rm -v $(pwd):/src aquasec/tfsec /src
```

## Best Practices

### DO ✅

1. **Always branch from the correct base branch**
   - Features from `development`
   - Hotfixes from `main`

2. **Keep branches up to date**
   ```bash
   git checkout feature/my-feature
   git pull origin development
   ```

3. **Small, focused changes**
   - One feature per branch
   - Easy to review and test

4. **Descriptive branch names and commits**

5. **Test before creating PR**
   ```bash
   terraform fmt -recursive
   terraform validate
   terraform plan
   ```

6. **Delete merged branches**
   ```bash
   git branch -d feature/my-feature
   git push origin --delete feature/my-feature
   ```

7. **Use draft PRs for work in progress**

### DON'T ❌

1. **Don't commit directly to main, staging, or development**
2. **Don't merge without testing**
3. **Don't commit secrets or sensitive data**
4. **Don't create long-lived feature branches**
5. **Don't skip code reviews**
6. **Don't merge broken code**
7. **Don't ignore CI/CD failures**

## Quick Reference Commands

### Start New Feature
```bash
git checkout development
git pull origin development
git checkout -b feature/my-new-feature
# ... make changes ...
git add .
git commit -m "feat: add new feature"
git push -u origin feature/my-new-feature
```

### Update Feature Branch
```bash
git checkout feature/my-feature
git fetch origin
git merge origin/development
# or
git rebase origin/development
```

### Create PR via CLI (using GitHub CLI)
```bash
gh pr create --base development --head feature/my-feature \
  --title "feat: add new feature" \
  --body "Description of changes"
```

### Promote to Next Environment
```bash
# From development to staging
git checkout staging
git pull origin staging
git merge development
git push origin staging

# From staging to main
git checkout main
git pull origin main
git merge staging
git push origin main
```

## Emergency Procedures

### Rollback Production

```bash
# Option 1: Revert the merge commit
git checkout main
git revert -m 1 <merge-commit-hash>
git push origin main

# Option 2: Cherry-pick previous working state
git checkout main
git cherry-pick <last-working-commit>
git push origin main

# Trigger deployment
```

### Fix Broken Deployment

```bash
# Create hotfix from current main
git checkout main
git pull origin main
git checkout -b hotfix/fix-broken-deployment

# Fix the issue
# ... make changes ...

# Fast-track to production
git add .
git commit -m "hotfix: fix broken deployment"
git push -u origin hotfix/fix-broken-deployment

# Create emergency PR with expedited review
```

## Additional Resources

- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitFlow Workflow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- [GitHub Flow](https://guides.github.com/introduction/flow/)

---

**Questions?** Open a discussion or contact the infrastructure team.
