#!/bin/bash

# DriMain API Examples using curl
# 
# NOTE: This file demonstrates the complete authentication flow including refresh tokens

echo "=== DriMain API Examples ==="

# Base URL
BASE_URL="http://localhost:8080"

echo "1. Login and save tokens"
LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}')

echo "Login response: $LOGIN_RESPONSE"

# Extract tokens using jq (install with: sudo apt-get install jq)
ACCESS_TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.token')
REFRESH_TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.refreshToken')

echo "Access token: ${ACCESS_TOKEN:0:50}..."
echo "Refresh token: ${REFRESH_TOKEN:0:50}..."

echo ""
echo "2. Use access token to get user info"
curl -s -X GET "$BASE_URL/api/users/me" \
  -H "Authorization: Bearer $ACCESS_TOKEN" | jq '.'

echo ""
echo "3. Use access token to access protected endpoint"
curl -s -X GET "$BASE_URL/api/raporty" \
  -H "Authorization: Bearer $ACCESS_TOKEN" | jq '.content | length'

echo ""
echo "4. Try to create a report (requires ADMIN role)"
CREATE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/raporty" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"typNaprawy":"Test Repair","opis":"API test description"}')

echo "Create report response: $CREATE_RESPONSE"

echo ""
echo "5. Refresh access token using refresh token"
REFRESH_RESPONSE=$(curl -s -X POST "$BASE_URL/api/auth/refresh" \
  -H "Content-Type: application/json" \
  -d "{\"refreshToken\":\"$REFRESH_TOKEN\"}")

echo "Refresh response: $REFRESH_RESPONSE"

# Extract new access token
NEW_ACCESS_TOKEN=$(echo $REFRESH_RESPONSE | jq -r '.token')
echo "New access token: ${NEW_ACCESS_TOKEN:0:50}..."

echo ""
echo "6. Use new access token"
curl -s -X GET "$BASE_URL/api/users/me" \
  -H "Authorization: Bearer $NEW_ACCESS_TOKEN" | jq '.'

echo ""
echo "=== Examples completed ==="

echo ""
echo "Note: These examples assume:"
echo "- DriMain application is running on localhost:8080"
echo "- Default admin user (admin/admin123) exists"
echo "- jq is installed for JSON parsing (optional but recommended)"