#!/bin/bash

# DriMain API Examples
# Make sure the application is running on http://localhost:8080

BASE_URL="http://localhost:8080"

echo "=== DriMain API Examples ==="
echo ""

# Login and get JWT token
echo "1. Login (Admin user):"
LOGIN_RESPONSE=$(curl -s -X POST $BASE_URL/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}')

echo "Response: $LOGIN_RESPONSE"
echo ""

# Extract token from response (assuming jq is available, otherwise manual)
if command -v jq &> /dev/null; then
    TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.token')
    echo "Extracted token: $TOKEN"
else
    echo "Note: Install 'jq' to automatically extract token, or copy it manually from the response above"
    echo "TOKEN=\"your_token_here\""
    TOKEN="your_token_here"
fi

echo ""

# Check if we have a valid token
if [ "$TOKEN" != "null" ] && [ "$TOKEN" != "your_token_here" ] && [ -n "$TOKEN" ]; then
    echo "2. Get user info:"
    curl -s -H "Authorization: Bearer $TOKEN" $BASE_URL/api/auth/me | jq '.' 2>/dev/null || curl -s -H "Authorization: Bearer $TOKEN" $BASE_URL/api/auth/me
    echo ""
    echo ""

    echo "3. List reports:"
    curl -s -H "Authorization: Bearer $TOKEN" $BASE_URL/api/raporty | jq '.' 2>/dev/null || curl -s -H "Authorization: Bearer $TOKEN" $BASE_URL/api/raporty
    echo ""
    echo ""

    echo "4. Create new report:"
    NEW_REPORT=$(curl -s -X POST $BASE_URL/api/raporty \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d '{
        "opis": "Test report from API",
        "status": "NOWY",
        "dataNaprawy": "2024-01-15",
        "maszynaId": 1
      }')
    echo "New report: $NEW_REPORT"
    echo ""

    echo "5. List parts (magazyn):"
    curl -s -H "Authorization: Bearer $TOKEN" $BASE_URL/api/czesci | jq '.' 2>/dev/null || curl -s -H "Authorization: Bearer $TOKEN" $BASE_URL/api/czesci
    echo ""
    echo ""

    echo "6. List issues (zgloszenia):"
    curl -s -H "Authorization: Bearer $TOKEN" $BASE_URL/api/zgloszenia | jq '.' 2>/dev/null || curl -s -H "Authorization: Bearer $TOKEN" $BASE_URL/api/zgloszenia
    echo ""

else
    echo "Token extraction failed. Please run the login command manually and set TOKEN variable:"
    echo ""
    echo "TOKEN=\$(curl -s -X POST $BASE_URL/api/auth/login \\"
    echo "  -H \"Content-Type: application/json\" \\"
    echo "  -d '{\"username\":\"admin\",\"password\":\"admin123\"}' | jq -r '.token')"
    echo ""
    echo "Then use the token in subsequent requests:"
    echo "curl -H \"Authorization: Bearer \$TOKEN\" $BASE_URL/api/raporty"
fi

echo ""
echo "=== Additional endpoints to test ==="
echo "- Health check: curl $BASE_URL/actuator/health"
echo "- Swagger UI: $BASE_URL/swagger-ui/index.html"
echo "- API docs: $BASE_URL/v3/api-docs"
echo ""
echo "=== Admin endpoints (ROLE_ADMIN required) ==="
echo "- Users: curl -H \"Authorization: Bearer \$TOKEN\" $BASE_URL/api/admin/users"
echo "- Departments: curl -H \"Authorization: Bearer \$TOKEN\" $BASE_URL/api/admin/dzialy" 
echo "- Machines: curl -H \"Authorization: Bearer \$TOKEN\" $BASE_URL/api/admin/maszyny"
echo "- Personnel: curl -H \"Authorization: Bearer \$TOKEN\" $BASE_URL/api/admin/osoby"