# Lambda VPC RDS Connection Guide

This guide explains how the Lambda VPC function connects to RDS and performs database operations.

## Current Implementation

### 1. Basic Connectivity Test (Current Stack)
The current Lambda VPC stack (`lambda-vpc-stack.yaml`) includes:

- **TCP Connection Test**: Tests basic connectivity to RDS using Node.js `net` module
- **Secrets Manager Integration**: Retrieves database credentials securely
- **Security Group Configuration**: Lambda can access RDS on port 3306
- **VPC Integration**: Lambda runs in private subnets with RDS access

### 2. Full Database Operations (Separate File)
The file `lambda-function-with-mysql2.js` contains the complete implementation with:

- **MySQL2 Integration**: Full database operations
- **Table Creation**: Creates `test_items` table if it doesn't exist
- **Data Insertion**: Inserts test records
- **Data Retrieval**: Fetches and displays data
- **Error Handling**: Comprehensive error handling and logging

## Architecture Overview

```
Internet → Lambda Function URL (IAM Auth) → Lambda Function (VPC) → RDS MySQL
                ↓
        Secrets Manager (Credentials)
```

## Security Features

✅ **IAM Authentication**: Function URL requires IAM authentication  
✅ **VPC Isolation**: Lambda runs in private subnets  
✅ **Secrets Manager**: Database credentials stored securely  
✅ **Security Groups**: Restricted access between Lambda and RDS  
✅ **Environment Variables**: Dynamic configuration per environment  

## Testing the Connection

### Step 1: Deploy Required Stacks
```bash
# Deploy VPC stack
cd cloudformation/vpc
./deploy-simple-vpc.sh

# Deploy RDS stack
cd ../rds
./deploy-rds.sh

# Deploy Secrets Manager stack
cd ../secrets-manager
./deploy-secrets.sh

# Update secrets with RDS endpoint
cd ..
./update-secret.sh

# Deploy Lambda VPC stack
cd lambda-vpc
./deploy-lambda-vpc.sh
```

### Step 2: Test Basic Connectivity
```bash
# Run the comprehensive test script
chmod +x test-lambda-rds-connection.sh
./test-lambda-rds-connection.sh

# Or test with different event types
chmod +x test-with-events.sh
./test-with-events.sh
```

### Step 3: Enable Full Database Operations
```bash
# Create mysql2 Lambda layer
chmod +x create-mysql2-layer.sh
./create-mysql2-layer.sh

# Update Lambda function with layer and full code
# (Manual step - update CloudFormation template)
```

## Database Operations

### Current Operations (Basic Test)
- ✅ Retrieve credentials from Secrets Manager
- ✅ Test TCP connectivity to RDS
- ✅ Validate endpoint and port accessibility

### Full Operations (with mysql2)
- ✅ Create database connection
- ✅ Create `test_items` table
- ✅ Insert test records
- ✅ Retrieve inserted data
- ✅ Count total records
- ✅ List recent items

## Sample Database Schema

```sql
CREATE TABLE test_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

## Expected Test Results

### Successful Connection Test
```json
{
  "statusCode": 200,
  "body": {
    "message": "Successfully tested RDS connectivity!",
    "connectionTest": {
      "status": "connected",
      "message": "TCP connection to RDS successful",
      "endpoint": "dev-rds-instance.xxxxx.ap-southeast-2.rds.amazonaws.com",
      "port": 3306
    },
    "credentials": {
      "host": "dev-rds-instance.xxxxx.ap-southeast-2.rds.amazonaws.com",
      "database": "devdb",
      "username": "admin",
      "port": 3306
    }
  }
}
```

### Successful Database Operations (with mysql2)
```json
{
  "statusCode": 200,
  "body": {
    "message": "Successfully connected to RDS and performed database operations!",
    "databaseOperations": {
      "connection": "successful",
      "tableCreation": "successful",
      "insert": "successful",
      "select": "successful"
    },
    "insertedItem": {
      "id": 1,
      "name": "Test Item 1703123456789",
      "description": "This is a test item created at 2023-12-21T10:30:56.789Z",
      "created_at": "2023-12-21T10:30:56.000Z",
      "updated_at": "2023-12-21T10:30:56.000Z"
    },
    "totalItems": 1,
    "recentItems": [...]
  }
}
```

## Troubleshooting

### Common Issues

1. **Connection Timeout**
   - Check if RDS instance is running
   - Verify security group allows Lambda access
   - Check VPC and subnet configuration

2. **Authentication Errors**
   - Verify Secrets Manager has correct credentials
   - Check Lambda execution role permissions
   - Ensure secret name matches environment

3. **VPC Issues**
   - Verify Lambda is in correct subnets
   - Check route table configuration
   - Ensure NAT Gateway/Internet Gateway setup

4. **Database Errors (with mysql2)**
   - Verify mysql2 layer is attached to Lambda
   - Check database exists and is accessible
   - Verify user permissions on database

### Debug Commands

```bash
# Check Lambda function status
aws lambda get-function --function-name dev-lambda-vpc-function --region ap-southeast-2

# Check CloudWatch logs (using exported log group name)
LOG_GROUP=$(aws cloudformation describe-stacks --stack-name dev-lambda-vpc-stack --region ap-southeast-2 --query 'Stacks[0].Outputs[?OutputKey==`LogGroupName`].OutputValue' --output text)
aws logs describe-log-streams --log-group-name $LOG_GROUP --region ap-southeast-2

# Test with different event types
./test-with-events.sh

# Test RDS connectivity from Lambda subnet
aws ec2 describe-instances --filters "Name=tag:Name,Values=*lambda*" --region ap-southeast-2

# Check security group rules
aws ec2 describe-security-groups --group-ids sg-xxxxxxxxx --region ap-southeast-2
```

## Next Steps

1. **Deploy the stacks** in the correct order
2. **Run the test script** to verify connectivity
3. **Create mysql2 layer** for full database operations
4. **Update Lambda function** with complete database code
5. **Test full CRUD operations** on the database

## Security Best Practices

- ✅ Use IAM authentication for Lambda URLs
- ✅ Store credentials in Secrets Manager
- ✅ Run Lambda in private subnets
- ✅ Use security groups to restrict access
- ✅ Enable CloudWatch logging
- ✅ Use environment-specific configurations
- ⚠️ Consider restricting RDS security group to Lambda SG only
- ⚠️ Implement proper error handling and logging
- ⚠️ Use parameterized queries to prevent SQL injection 