#!/bin/bash

# Lambda VPC Stack Deployment Script
# This script deploys the Lambda function with VPC access and RDS integration

set -e

# Configuration
STACK_NAME="dev-lambda-vpc-stack"
TEMPLATE_FILE="lambda-vpc-stack.yaml"
REGION="ap-southeast-2"

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

# Check if template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    print_error "Template file $TEMPLATE_FILE not found!"
    exit 1
fi

# Check if VPC stack exists
if ! aws cloudformation describe-stacks --stack-name dev-vpc-stack --region $REGION > /dev/null 2>&1; then
    print_error "VPC stack 'dev-vpc-stack' not found! Please deploy the VPC stack first."
    exit 1
fi

# Check if Secrets Manager stack exists
if ! aws cloudformation describe-stacks --stack-name dev-secrets-stack --region $REGION > /dev/null 2>&1; then
    print_error "Secrets Manager stack 'dev-secrets-stack' not found! Please deploy the Secrets Manager stack first."
    exit 1
fi

# Validate CloudFormation template
print_status "Validating CloudFormation template..."
if aws cloudformation validate-template --template-body file://$TEMPLATE_FILE --region $REGION > /dev/null; then
    print_status "Template validation successful!"
else
    print_error "Template validation failed!"
    exit 1
fi

# Check if stack already exists
if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION > /dev/null 2>&1; then
    print_warning "Stack $STACK_NAME already exists. Updating..."
    OPERATION="update-stack"
else
    print_status "Creating new stack $STACK_NAME..."
    OPERATION="create-stack"
fi

# Deploy the stack
print_status "Deploying CloudFormation stack..."
if aws cloudformation $OPERATION \
    --stack-name $STACK_NAME \
    --template-body file://$TEMPLATE_FILE \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters \
        ParameterKey=FunctionName,ParameterValue=dev-lambda-vpc-function \
        ParameterKey=Environment,ParameterValue=dev \
    --region $REGION; then
    
    print_status "Stack deployment initiated successfully!"
    
    # Wait for stack to complete
    print_status "Waiting for stack deployment to complete..."
    print_warning "This may take a few minutes for Lambda function creation..."
    aws cloudformation wait stack-$([ "$OPERATION" = "create-stack" ] && echo "create" || echo "update")-complete \
        --stack-name $STACK_NAME \
        --region $REGION
    
    print_status "Stack deployment completed successfully!"
    
    # Get stack outputs
    print_status "Retrieving stack outputs..."
    aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs' \
        --output table
    
    # Display important information
    print_status "Lambda VPC Resources Created:"
    print_status "- Lambda function with VPC access"
    print_status "- IAM role with Secrets Manager and VPC permissions"
    print_status "- Security group for Lambda"
    print_status "- Function URL for HTTP access"
    print_status "- CloudWatch alarms for monitoring"
    print_warning "Note: Lambda function is configured to access RDS via Secrets Manager"
    
else
    print_error "Stack deployment failed!"
    exit 1
fi

print_status "Lambda VPC deployment completed successfully!" 