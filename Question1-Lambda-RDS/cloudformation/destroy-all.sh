#!/bin/bash

# Complete CloudFormation Stack Destruction Script
# This script destroys all stacks in the correct order

set -e

# Configuration
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

# Function to check if stack exists
stack_exists() {
    local stack_name=$1
    aws cloudformation describe-stacks --stack-name $stack_name --region $REGION > /dev/null 2>&1
}

# Function to delete stack
delete_stack() {
    local stack_name=$1
    local description=$2
    
    if stack_exists $stack_name; then
        print_status "Deleting $description ($stack_name)..."
        aws cloudformation delete-stack --stack-name $stack_name --region $REGION
        
        print_status "Waiting for $description deletion to complete..."
        aws cloudformation wait stack-delete-complete --stack-name $stack_name --region $REGION
        
        print_status "$description deleted successfully!"
    else
        print_warning "$description ($stack_name) does not exist, skipping..."
    fi
}

print_status "Starting complete cleanup of all CloudFormation stacks..."
print_warning "This will destroy ALL resources including VPC, RDS, Lambda, and Secrets Manager!"
echo

# Delete stacks in reverse dependency order
print_status "Step 1: Deleting Lambda VPC Stack (depends on VPC, RDS, Secrets)..."
delete_stack "dev-lambda-vpc-stack" "Lambda VPC Stack"

print_status "Step 2: Deleting Secrets Manager Stack..."
delete_stack "dev-secrets-stack" "Secrets Manager Stack"

print_status "Step 3: Deleting RDS Stack (depends on VPC)..."
delete_stack "dev-rds-stack" "RDS Stack"

print_status "Step 4: Deleting Lambda No-VPC Stack..."
delete_stack "dev-lambda-stack" "Lambda No-VPC Stack"

print_status "Step 5: Deleting VPC Stack..."
delete_stack "dev-vpc-stack" "VPC Stack"

print_status "Step 6: Checking for any remaining stacks..."
aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --region $REGION --query 'StackSummaries[?contains(StackName, `dev-`)].{StackName:StackName,Status:StackStatus}' --output table

print_status "Complete cleanup finished!"
print_status "All CloudFormation stacks have been destroyed." 