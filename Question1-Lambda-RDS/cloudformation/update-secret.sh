#!/bin/bash

# Update Secrets Manager with RDS Endpoint
# This script updates the secret with the actual RDS endpoint

set -e

# Configuration
REGION="ap-southeast-2"
SECRET_NAME="dev/rds/credentials"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if RDS stack exists
if ! aws cloudformation describe-stacks --stack-name dev-rds-stack --region $REGION > /dev/null 2>&1; then
    print_error "RDS stack 'dev-rds-stack' not found! Please deploy the RDS stack first."
    exit 1
fi

# Get RDS endpoint
print_status "Getting RDS endpoint..."
RDS_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name dev-rds-stack \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`DBEndpoint`].OutputValue' \
    --output text)

if [ -z "$RDS_ENDPOINT" ] || [ "$RDS_ENDPOINT" = "None" ]; then
    print_error "Could not retrieve RDS endpoint from CloudFormation stack."
    exit 1
fi

print_status "RDS Endpoint: $RDS_ENDPOINT"

# Get current secret value
print_status "Getting current secret value..."
SECRET_VALUE=$(aws secretsmanager get-secret-value \
    --secret-id $SECRET_NAME \
    --region $REGION \
    --query 'SecretString' \
    --output text)

if [ -z "$SECRET_VALUE" ]; then
    print_error "Could not retrieve secret value."
    exit 1
fi

# Update secret with RDS endpoint
print_status "Updating secret with RDS endpoint..."
UPDATED_SECRET=$(echo $SECRET_VALUE | sed "s/RDS_ENDPOINT_PLACEHOLDER/$RDS_ENDPOINT/g")

# Update the secret
aws secretsmanager update-secret \
    --secret-id $SECRET_NAME \
    --secret-string "$UPDATED_SECRET" \
    --region $REGION

print_status "Secret updated successfully!"
print_status "Secret now contains the actual RDS endpoint: $RDS_ENDPOINT"
print_warning "Note: The Lambda function can now connect to RDS using the credentials from Secrets Manager" 