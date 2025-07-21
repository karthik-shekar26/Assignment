#!/bin/bash

# Create MySQL2 Lambda Layer Script
# This script creates a Lambda layer with mysql2 for database operations

set -e

# Configuration
REGION="ap-southeast-2"
LAYER_NAME="mysql2-layer"
LAYER_VERSION="1"

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
    echo -e "${BLUE}[LAYER]${NC} $1"
}

# Check if required tools are installed
if ! command -v node &> /dev/null; then
    print_error "Node.js is not installed. Please install it first."
    exit 1
fi

if ! command -v npm &> /dev/null; then
    print_error "npm is not installed. Please install it first."
    exit 1
fi

if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Create temporary directory
print_header "Creating temporary directory for layer..."
TEMP_DIR=$(mktemp -d)
LAYER_DIR="$TEMP_DIR/nodejs"
mkdir -p "$LAYER_DIR"

print_status "Temporary directory: $TEMP_DIR"

# Install mysql2
print_header "Installing mysql2 package..."
cd "$LAYER_DIR"
npm init -y > /dev/null
npm install mysql2@^3.0.0

print_status "mysql2 installed successfully"

# Create layer ZIP file
print_header "Creating layer ZIP file..."
cd "$TEMP_DIR"
zip -r mysql2-layer.zip nodejs/ > /dev/null

print_status "Layer ZIP created: mysql2-layer.zip"

# Check if layer already exists
print_header "Checking if layer already exists..."
if aws lambda get-layer-version --layer-name $LAYER_NAME --version-number $LAYER_VERSION --region $REGION > /dev/null 2>&1; then
    print_warning "Layer version $LAYER_NAME:$LAYER_VERSION already exists."
    read -p "Do you want to create a new version? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Get the next available version
        LAYER_VERSION=$(aws lambda list-layer-versions --layer-name $LAYER_NAME --region $REGION --query 'LayerVersions[0].Version' --output text 2>/dev/null || echo "0")
        LAYER_VERSION=$((LAYER_VERSION + 1))
        print_status "Creating new version: $LAYER_VERSION"
    else
        print_status "Skipping layer creation."
        exit 0
    fi
fi

# Create Lambda layer
print_header "Creating Lambda layer..."
LAYER_ARN=$(aws lambda publish-layer-version \
    --layer-name $LAYER_NAME \
    --description "MySQL2 package for Lambda functions" \
    --license-info "MIT" \
    --zip-file fileb://mysql2-layer.zip \
    --compatible-runtimes nodejs18.x \
    --region $REGION \
    --query 'LayerVersionArn' \
    --output text)

if [ $? -eq 0 ]; then
    print_status "✅ SUCCESS: Lambda layer created successfully!"
    print_status "Layer ARN: $LAYER_ARN"
    print_status "Layer Name: $LAYER_NAME"
    print_status "Layer Version: $LAYER_VERSION"
    
    print_header "Next steps to use this layer:"
    print_status "1. Update your Lambda function to include this layer:"
    echo "   Layers:"
    echo "     - $LAYER_ARN"
    print_status "2. Update your Lambda function code to use mysql2:"
    echo "   const mysql = require('mysql2/promise');"
    print_status "3. Use the complete function code from lambda-function-with-mysql2.js"
    
else
    print_error "❌ FAILED: Failed to create Lambda layer"
    exit 1
fi

# Clean up
print_header "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"
print_status "Cleanup completed"

print_status "MySQL2 Lambda layer creation completed successfully!" 