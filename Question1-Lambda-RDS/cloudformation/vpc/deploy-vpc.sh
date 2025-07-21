#!/bin/bash

# VPC Stack Deployment Script
# This script deploys the VPC with private subnets using CloudFormation

set -e

# Configuration
STACK_NAME="dev-vpc-stack"
TEMPLATE_FILE="vpc-stack.yaml"
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
    --parameters \
        ParameterKey=VpcName,ParameterValue=dev-vpc \
        ParameterKey=Environment,ParameterValue=dev \
        ParameterKey=VpcCidr,ParameterValue=10.0.0.0/16 \
        ParameterKey=PrivateSubnet1Cidr,ParameterValue=10.0.1.0/24 \
        ParameterKey=PrivateSubnet2Cidr,ParameterValue=10.0.2.0/24 \
    --region $REGION; then
    
    print_status "Stack deployment initiated successfully!"
    
    # Wait for stack to complete
    print_status "Waiting for stack deployment to complete..."
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
    print_status "VPC Resources Created:"
    print_status "- VPC with CIDR: 10.0.0.0/16"
    print_status "- 2 Private Subnets across different AZs"
    print_status "- NAT Gateway for outbound internet access"
    print_status "- Internet Gateway"
    print_status "- Default Security Group"
    
else
    print_error "Stack deployment failed!"
    exit 1
fi

print_status "VPC deployment completed successfully!" 