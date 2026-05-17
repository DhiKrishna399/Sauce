#!/bin/bash

BASE_URL="http://localhost:3000"

# Create a simple 1x1 pixel PNG as base64 for testing (red pixel)
# This is a minimal valid PNG
TEST_IMAGE="iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="

echo "========================================"
echo "GUIDEBOT FEATURE TESTS"
echo "========================================"
echo ""

# Test 1: Health Check
echo "1. HEALTH CHECK"
echo "----------------"
curl -s "$BASE_URL/health" | jq .
echo ""

# Test 2: Guide Mode (Screen Content Steps)
echo "2. GUIDE MODE - Screen Content Steps"
echo "-------------------------------------"
echo "Request: How do I open settings?"
curl -s -X POST "$BASE_URL/analyze" \
  -H "Content-Type: application/json" \
  -d '{
    "imageBase64": "'"$TEST_IMAGE"'",
    "query": "How do I find the settings button?",
    "mode": "guide",
    "context": {"appName": "Test App"}
  }' | jq '.mode, .answerType, .explanation, .steps[0:2]'
echo ""

# Test 3: Action Mode - Phone Call (using test endpoint)
echo "3. ACTION MODE - Phone Call (Simulated)"
echo "----------------------------------------"
echo "Request: Simulate a reservation call"
curl -s -X POST "$BASE_URL/test/simulate-call" \
  -H "Content-Type: application/json" \
  -d '{
    "restaurantName": "The Italian Place",
    "phoneNumber": "+15551234567",
    "partySize": 4,
    "date": "Tonight",
    "time": "7:30 PM"
  }' | jq '.intent, .status, .message, .callId'
echo ""

# Test 4: Action Mode - Email (Mock Mode)
echo "4. ACTION MODE - Email"
echo "-----------------------"
echo "Request: Email test@example.com to ask about availability"
curl -s -X POST "$BASE_URL/analyze" \
  -H "Content-Type: application/json" \
  -d '{
    "imageBase64": "'"$TEST_IMAGE"'",
    "query": "Email test@example.com to ask about availability for a private event",
    "mode": "action",
    "context": {"appName": "Restaurant Page"}
  }' | jq '.mode, .type, .intent, .status, .message, .details'
echo ""

# Test 5: Get Call Status (for the simulated call)
echo "5. CALL STATUS CHECK"
echo "--------------------"
# First get a call ID
CALL_RESPONSE=$(curl -s -X POST "$BASE_URL/test/simulate-call" \
  -H "Content-Type: application/json" \
  -d '{"restaurantName": "Test Cafe"}')
CALL_ID=$(echo $CALL_RESPONSE | jq -r '.callId')
echo "Checking status for call: $CALL_ID"
sleep 2
curl -s "$BASE_URL/test/call-status/$CALL_ID" | jq '.status, .message'
echo ""

echo "========================================"
echo "ALL TESTS COMPLETED"
echo "========================================"
