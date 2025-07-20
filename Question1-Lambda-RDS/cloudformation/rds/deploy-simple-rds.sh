#!/bin/bash

# Simple RDS Stack Deployment Script
# This script deploys the RDS MySQL instance using CloudFormation

set -e

# Configuration
STACK_NAME="dev-rds-stack"
TEMPLATE_FILE="simple-rds-stack.yaml"
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

# Prompt for database password
print_status "Please enter a database password (minimum 8 characters):"
read -s DB_PASSWORD

if [ ${#DB_PASSWORD} -lt 8 ]; then
    print_error "Password must be at least 8 characters long!"
    exit 1
fi

# Deploy the stack
print_status "Deploying CloudFormation stack..."
if aws cloudformation $OPERATION \
    --stack-name $STACK_NAME \
    --template-body file://$TEMPLATE_FILE \
    --parameters \
        ParameterKey=DBInstanceIdentifier,ParameterValue=dev-rds-instance \
        ParameterKey=Environment,ParameterValue=dev \
        ParameterKey=DBName,ParameterValue=devdb \
        ParameterKey=DBUsername,ParameterValue=admin \
        ParameterKey=DBPassword,ParameterValue="$DB_PASSWORD" \
        ParameterKey=DBInstanceClass,ParameterValue=db.t3.micro \
        ParameterKey=AllocatedStorage,ParameterValue=20 \
    --region $REGION; then
    
    print_status "Stack deployment initiated successfully!"
    
    # Wait for stack to complete
    print_status "Waiting for stack deployment to complete..."
    print_warning "This may take 5-10 minutes for RDS instance creation..."
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
    print_status "RDS Resources Created:"
    print_status "- MySQL 8.0.35 RDS Instance"
    print_status "- DB Subnet Group in VPC private subnets"
    print_status "- Security Group with MySQL port (3306) access"
    print_status "- Database: devdb"
    print_status "- Username: admin"
    print_warning "Note: RDS instance is in private subnets with no public access"
    
else
    print_error "Stack deployment failed!"
    exit 1
fi

print_status "RDS deployment completed successfully!" 