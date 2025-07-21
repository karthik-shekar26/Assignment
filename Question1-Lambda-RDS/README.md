# Lambda RDS Infrastructure

A production-ready AWS infrastructure template for Lambda functions with RDS connectivity, featuring comprehensive CI/CD pipelines, security scanning, and automated testing.

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   GitHub PR     │───▶│  GitHub Actions  │───▶│  AWS CloudFormation │
│   Validation    │    │  CI/CD Pipeline  │    │  Stacks         │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │  Lambda Function │
                       │  (VPC + RDS)     │
                       └──────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │  RDS MySQL       │
                       │  (Private Subnet)│
                       └──────────────────┘
```

## 🚀 Features

### Infrastructure
- ✅ **VPC with Private Subnets**: Secure network isolation
- ✅ **RDS MySQL Instance**: Managed database in private subnets
- ✅ **Lambda Function with VPC Access**: Serverless compute with database connectivity
- ✅ **Secrets Manager**: Secure credential management
- ✅ **CloudWatch Logging**: Comprehensive monitoring and debugging

### Security
- ✅ **IAM Authentication**: Secure Lambda function URLs
- ✅ **Security Groups**: Restricted network access
- ✅ **Encrypted Storage**: RDS encryption at rest
- ✅ **Secrets Management**: No hardcoded credentials
- ✅ **Security Scanning**: Automated vulnerability detection

### CI/CD Pipeline
- ✅ **Automated Testing**: Linting, validation, and security scans
- ✅ **Multi-Environment Deployment**: Staging and production
- ✅ **Pull Request Protection**: Required checks before merging
- ✅ **Infrastructure as Code**: Version-controlled deployments
- ✅ **Rollback Capability**: CloudFormation stack management

## 📋 Prerequisites

### Local Development
- AWS CLI v2.x
- Node.js 18.x
- Python 3.11+
- jq (JSON processor)
- Git

### AWS Requirements
- AWS Account with appropriate permissions
- IAM user/role with CloudFormation, Lambda, RDS, VPC, and Secrets Manager permissions
- Access to ap-southeast-2 region (configurable)

### GitHub Requirements
- GitHub repository with Actions enabled
- GitHub Secrets configured (see Setup section)

## 🛠️ Setup

### 1. Repository Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/lambda-rds-infrastructure.git
cd lambda-rds-infrastructure

# Install dependencies
npm install

# Make scripts executable
chmod +x cloudformation/**/*.sh
chmod +x test-*.sh
chmod +x create-mysql2-layer.sh
```

### 2. GitHub Secrets Configuration

Configure the following secrets in your GitHub repository:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS Access Key ID | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Access Key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `DB_PASSWORD` | RDS Database Password | `MySecurePassword123!` |

**To configure secrets:**
1. Go to your GitHub repository
2. Navigate to Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Add each secret with appropriate values

### 3. Branch Protection Rules

Set up branch protection for the `main` branch:

1. Go to Settings → Branches
2. Add rule for `main` branch
3. Enable:
   - ✅ Require a pull request before merging
   - ✅ Require status checks to pass before merging
   - ✅ Require branches to be up to date before merging
   - ✅ Include administrators
4. Select required status checks:
   - `validate-changes`
   - `security-scan-pr`
   - `test-scripts`
   - `check-deployment-order`

## 🔄 CI/CD Pipeline

### Pull Request Workflow
When a PR is created against `main`:

1. **Validate Changes**: Lint and validate CloudFormation templates
2. **Security Scan**: Run Checkov security scanning
3. **Test Scripts**: Validate script and JSON syntax
4. **Check Dependencies**: Verify deployment order
5. **Generate Summary**: Create PR summary with changes

### Deployment Workflow
When code is merged:

#### Staging (develop branch)
- Deploy VPC stack
- Deploy RDS stack
- Deploy Secrets Manager stack
- Update secrets with RDS endpoint
- Deploy Lambda VPC stack
- Run connectivity tests

#### Production (main branch)
- Deploy all infrastructure stacks
- Run comprehensive tests
- Create MySQL2 Lambda layer
- Generate deployment report

## 📁 Project Structure

```
lambda-rds-infrastructure/
├── .github/
│   └── workflows/
│       ├── deploy.yml          # Main deployment workflow
│       └── pr-checks.yml       # Pull request validation
├── cloudformation/
│   ├── vpc/
│   │   ├── simple-vpc-stack.yaml
│   │   └── deploy-simple-vpc.sh
│   ├── rds/
│   │   ├── rds-stack.yaml
│   │   └── deploy-rds.sh
│   ├── secrets-manager/
│   │   ├── secrets-stack.yaml
│   │   └── deploy-secrets.sh
│   ├── lambda-vpc/
│   │   ├── lambda-vpc-stack.yaml
│   │   ├── deploy-lambda-vpc.sh
│   │   └── TestEvent.json
│   └── update-secret.sh
├── scripts/
│   ├── test-lambda-rds-connection.sh
│   ├── test-with-events.sh
│   └── create-mysql2-layer.sh
├── lambda-function-with-mysql2.js
├── RDS-CONNECTION-GUIDE.md
├── package.json
└── README.md
```

## 🧪 Testing

### Local Testing

```bash
# Test CloudFormation templates
npm run lint
npm run validate

# Test Lambda RDS connectivity
npm run test:connectivity

# Test with different event types
npm run test:events
```

### Automated Testing

The CI/CD pipeline automatically runs:

- **CloudFormation Linting**: `cfn-lint` validation
- **Template Validation**: AWS CloudFormation validation
- **Security Scanning**: Checkov vulnerability detection
- **Script Syntax**: Bash script validation
- **JSON Validation**: JSON syntax checking
- **Deployment Testing**: Post-deployment connectivity tests

## 🔧 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `AWS_REGION` | AWS region for deployment | `ap-southeast-2` |
| `ENVIRONMENT` | Environment name | `dev` |

### Customization

To customize the infrastructure:

1. **Change Region**: Update `AWS_REGION` in workflows
2. **Modify VPC**: Edit `cloudformation/vpc/simple-vpc-stack.yaml`
3. **Adjust RDS**: Modify `cloudformation/rds/rds-stack.yaml`
4. **Update Lambda**: Edit `cloudformation/lambda-vpc/lambda-vpc-stack.yaml`

## 📊 Monitoring

### CloudWatch Logs
- Lambda function logs: `/aws/lambda/dev-lambda-vpc-function`
- Access via AWS Console or CLI

### CloudWatch Alarms
- Lambda error rate monitoring
- Lambda duration monitoring
- Automatic alerting on issues

### Security Monitoring
- Checkov security scan results in GitHub Security tab
- SARIF format for integration with security tools

## 🚨 Troubleshooting

### Common Issues

1. **Deployment Failures**
   ```bash
   # Check CloudFormation stack status
   aws cloudformation describe-stacks --stack-name dev-lambda-vpc-stack
   
   # View stack events
   aws cloudformation describe-stack-events --stack-name dev-lambda-vpc-stack
   ```

2. **Lambda Connection Issues**
   ```bash
   # Test connectivity
   ./test-lambda-rds-connection.sh
   
   # Check security groups
   aws ec2 describe-security-groups --group-ids sg-xxxxxxxxx
   ```

3. **GitHub Actions Failures**
   - Check Actions tab for detailed logs
   - Verify GitHub secrets are configured
   - Ensure branch protection rules are set

### Debug Commands

```bash
# Check Lambda function status
aws lambda get-function --function-name dev-lambda-vpc-function

# Test RDS connectivity
aws rds describe-db-instances --db-instance-identifier dev-rds-instance

# Verify secrets
aws secretsmanager get-secret-value --secret-id dev/rds/credentials
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run local tests (`npm run lint && npm run validate`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Development Guidelines

- ✅ Follow CloudFormation best practices
- ✅ Include security scanning in changes
- ✅ Add tests for new functionality
- ✅ Update documentation for changes
- ✅ Use semantic commit messages

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- 📖 [Documentation](RDS-CONNECTION-GUIDE.md)
- 🐛 [Issues](https://github.com/yourusername/lambda-rds-infrastructure/issues)
- 💬 [Discussions](https://github.com/yourusername/lambda-rds-infrastructure/discussions)

## 🔄 Version History

- **v1.0.0**: Initial release with basic Lambda-RDS connectivity
- **v1.1.0**: Added CI/CD pipeline and security scanning
- **v1.2.0**: Enhanced testing and monitoring capabilities

---

**Note**: This is a production-ready template. Always review and customize according to your specific requirements before deploying to production environments. 