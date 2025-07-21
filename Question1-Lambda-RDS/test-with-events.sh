#!/bin/bash

# Test Lambda Function with Different Events
# This script helps test the Lambda function using events from TestEvent.json

set -e

# Configuration
REGION="ap-southeast-2"
FUNCTION_NAME="dev-lambda-vpc-function"
TEST_EVENTS_FILE="cloudformation/lambda-vpc/TestEvent.json"

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

# Check if required files exist
if [ ! -f "$TEST_EVENTS_FILE" ]; then
    print_error "Test events file not found: $TEST_EVENTS_FILE"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    print_error "jq is not installed. Please install it first."
    print_status "Install with: sudo apt-get install jq (Ubuntu/Debian) or brew install jq (macOS)"
    exit 1
fi

# Function to test with a specific event
test_event() {
    local event_name=$1
    local event_data=$2
    
    print_header "Testing with event: $event_name"
    print_status "Event data: $event_data"
    
    # Create temporary event file
    local temp_event_file=$(mktemp)
    echo "$event_data" > "$temp_event_file"
    
    # Invoke Lambda function
    local response_file=$(mktemp)
    aws lambda invoke \
        --function-name $FUNCTION_NAME \
        --payload file://"$temp_event_file" \
        --region $REGION \
        --cli-binary-format raw-in-base64-out \
        "$response_file" > /dev/null
    
    # Display response
    print_status "Response:"
    if [ -f "$response_file" ]; then
        cat "$response_file" | jq '.' 2>/dev/null || cat "$response_file"
        
        # Check for success
        if grep -q "Successfully tested RDS connectivity" "$response_file"; then
            print_status "✅ SUCCESS: $event_name test passed!"
        else
            print_warning "⚠️  WARNING: $event_name test may have issues"
        fi
        
        # Clean up
        rm -f "$response_file"
    fi
    
    rm -f "$temp_event_file"
    echo
}

# Display available test events
print_header "Available Test Events:"
jq -r '.events | to_entries[] | "\(.key): \(.value.name) - \(.value.description)"' "$TEST_EVENTS_FILE"

echo
print_status "Select a test event to run:"
echo "1. basic_test"
echo "2. database_operations"
echo "3. error_simulation"
echo "4. api_gateway_proxy"
echo "5. scheduled_event"
echo "6. secrets_test"
echo "7. vpc_connectivity"
echo "8. all (run all tests)"
echo "9. custom (enter custom JSON)"

read -p "Enter your choice (1-9): " choice

case $choice in
    1)
        event_data=$(jq -r '.events.basic_test.event' "$TEST_EVENTS_FILE")
        test_event "Basic Test" "$event_data"
        ;;
    2)
        event_data=$(jq -r '.events.database_operations.event' "$TEST_EVENTS_FILE")
        test_event "Database Operations" "$event_data"
        ;;
    3)
        event_data=$(jq -r '.events.error_simulation.event' "$TEST_EVENTS_FILE")
        test_event "Error Simulation" "$event_data"
        ;;
    4)
        event_data=$(jq -r '.events.api_gateway_proxy.event' "$TEST_EVENTS_FILE")
        test_event "API Gateway Proxy" "$event_data"
        ;;
    5)
        event_data=$(jq -r '.events.scheduled_event.event' "$TEST_EVENTS_FILE")
        test_event "Scheduled Event" "$event_data"
        ;;
    6)
        event_data=$(jq -r '.events.secrets_test.event' "$TEST_EVENTS_FILE")
        test_event "Secrets Test" "$event_data"
        ;;
    7)
        event_data=$(jq -r '.events.vpc_connectivity.event' "$TEST_EVENTS_FILE")
        test_event "VPC Connectivity" "$event_data"
        ;;
    8)
        print_header "Running all tests..."
        for event_name in $(jq -r '.events | keys[]' "$TEST_EVENTS_FILE"); do
            event_data=$(jq -r ".events.$event_name.event" "$TEST_EVENTS_FILE")
            test_event "$event_name" "$event_data"
            sleep 2  # Small delay between tests
        done
        print_status "✅ All tests completed!"
        ;;
    9)
        print_status "Enter custom JSON event (press Ctrl+D when done):"
        custom_event=$(cat)
        test_event "Custom Event" "$custom_event"
        ;;
    *)
        print_error "Invalid choice. Please run the script again."
        exit 1
        ;;
esac

print_header "Test Summary:"
print_status "✅ Event testing completed"
print_status "📊 Check CloudWatch logs for detailed execution information"
print_status "🔧 Use the test script for comprehensive connectivity testing" 