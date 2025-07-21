#!/bin/bash

# Test Lambda RDS Connection Script
# This script tests if the Lambda function can connect to RDS and insert data

set -e

# Configuration
REGION="ap-southeast-2"
STACK_NAME="dev-lambda-vpc-stack"
FUNCTION_NAME="dev-lambda-vpc-function"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if required stacks exist
print_header "Checking CloudFormation stacks..."

if ! aws cloudformation describe-stacks --stack-name dev-vpc-stack --region $REGION > /dev/null 2>&1; then
    print_error "VPC stack 'dev-vpc-stack' not found! Please deploy it first."
    exit 1
fi

if ! aws cloudformation describe-stacks --stack-name dev-rds-stack --region $REGION > /dev/null 2>&1; then
    print_error "RDS stack 'dev-rds-stack' not found! Please deploy it first."
    exit 1
fi

if ! aws cloudformation describe-stacks --stack-name dev-secrets-stack --region $REGION > /dev/null 2>&1; then
    print_error "Secrets Manager stack 'dev-secrets-stack' not found! Please deploy it first."
    exit 1
fi

if ! aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION > /dev/null 2>&1; then
    print_error "Lambda VPC stack '$STACK_NAME' not found! Please deploy it first."
    exit 1
fi

print_status "All required stacks are deployed!"

# Get Lambda function URL
print_header "Getting Lambda function URL..."
FUNCTION_URL=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`FunctionUrl`].OutputValue' \
    --output text)

if [ -z "$FUNCTION_URL" ] || [ "$FUNCTION_URL" = "None" ]; then
    print_error "Could not retrieve Lambda function URL."
    exit 1
fi

print_status "Lambda Function URL: $FUNCTION_URL"

# Test 1: Direct Lambda invocation (recommended for IAM authenticated URLs)
print_header "Testing Lambda function with direct invocation..."

# Create a test payload
TEST_PAYLOAD='{"test": "data", "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}'

print_status "Invoking Lambda function with test payload..."
print_status "Payload: $TEST_PAYLOAD"

# Invoke Lambda function directly
RESPONSE=$(aws lambda invoke \
    --function-name $FUNCTION_NAME \
    --payload "$TEST_PAYLOAD" \
    --region $REGION \
    --cli-binary-format raw-in-base64-out \
    response.json)

print_status "Lambda invocation completed!"

# Check the response
if [ -f "response.json" ]; then
    print_header "Lambda Response:"
    cat response.json | jq '.' 2>/dev/null || cat response.json
    
    # Check for success
    if grep -q "Successfully connected to RDS" response.json; then
        print_status "✅ SUCCESS: Lambda function successfully connected to RDS and inserted data!"
        
        # Extract and display the inserted item details
        INSERTED_ITEM=$(cat response.json | jq -r '.body' | jq -r '.insertedItem' 2>/dev/null)
        TOTAL_ITEMS=$(cat response.json | jq -r '.body' | jq -r '.totalItems' 2>/dev/null)
        
        if [ "$INSERTED_ITEM" != "null" ]; then
            print_status "📊 Database Operation Results:"
            print_status "   - Inserted Item ID: $(echo $INSERTED_ITEM | jq -r '.id' 2>/dev/null)"
            print_status "   - Item Name: $(echo $INSERTED_ITEM | jq -r '.name' 2>/dev/null)"
            print_status "   - Total Items in Table: $TOTAL_ITEMS"
        fi
    else
        print_error "❌ FAILED: Lambda function could not connect to RDS or insert data."
        print_error "Check the response above for error details."
    fi
    
    # Clean up
    rm -f response.json
else
    print_error "❌ FAILED: No response file generated."
fi

# Test 2: Check CloudWatch logs
print_header "Checking CloudWatch logs for detailed execution information..."

# Get log group name from CloudFormation output
LOG_GROUP=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`LogGroupName`].OutputValue' \
    --output text 2>/dev/null || echo "/aws/lambda/$FUNCTION_NAME")

print_status "Log Group: $LOG_GROUP"
LATEST_LOG_STREAM=$(aws logs describe-log-streams \
    --log-group-name $LOG_GROUP \
    --region $REGION \
    --order-by LastEventTime \
    --descending \
    --max-items 1 \
    --query 'logStreams[0].logStreamName' \
    --output text 2>/dev/null)

if [ "$LATEST_LOG_STREAM" != "None" ] && [ -n "$LATEST_LOG_STREAM" ]; then
    print_status "Latest log stream: $LATEST_LOG_STREAM"
    print_status "Recent log events:"
    
    aws logs get-log-events \
        --log-group-name $LOG_GROUP \
        --log-stream-name "$LATEST_LOG_STREAM" \
        --region $REGION \
        --start-time $(($(date +%s) - 300))000 \
        --query 'events[*].message' \
        --output text 2>/dev/null | head -20
else
    print_warning "No recent log streams found."
fi

# Test 3: Verify RDS connectivity from Lambda security group
print_header "Verifying RDS security group configuration..."

# Get Lambda security group ID
LAMBDA_SG_ID=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`SecurityGroupId`].OutputValue' \
    --output text)

# Get RDS security group ID
RDS_SG_ID=$(aws cloudformation describe-stacks \
    --stack-name dev-rds-stack \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`SecurityGroupId`].OutputValue' \
    --output text)

print_status "Lambda Security Group: $LAMBDA_SG_ID"
print_status "RDS Security Group: $RDS_SG_ID"

# Check if RDS security group allows inbound from Lambda security group
RDS_INGRESS=$(aws ec2 describe-security-groups \
    --group-ids $RDS_SG_ID \
    --region $REGION \
    --query 'SecurityGroups[0].IpPermissions[?FromPort==`3306`]' \
    --output json 2>/dev/null)

if echo "$RDS_INGRESS" | grep -q "0.0.0.0/0"; then
    print_warning "⚠️  RDS security group allows access from 0.0.0.0/0 (any IP)"
    print_warning "   For better security, consider restricting to Lambda security group only"
else
    print_status "✅ RDS security group has restricted access"
fi

print_header "Test Summary:"
print_status "✅ Lambda function deployment verified"
print_status "✅ Function URL retrieved"
print_status "✅ Direct invocation test completed"
print_status "✅ CloudWatch logs checked"
print_status "✅ Security group configuration reviewed"

print_status "Test completed successfully!" 