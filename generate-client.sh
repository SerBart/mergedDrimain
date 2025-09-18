#!/bin/bash

# Generate TypeScript client from OpenAPI spec
# This script downloads the OpenAPI spec from running server and generates TypeScript client

echo "Generating TypeScript client from OpenAPI spec..."

# Create client directory if it doesn't exist
mkdir -p client

# Start server in background to get OpenAPI spec
echo "Starting server to generate OpenAPI spec..."
./mvnw spring-boot:run &
SERVER_PID=$!

# Wait for server to start
sleep 15

# Download OpenAPI spec
echo "Downloading OpenAPI specification..."
curl -o client/openapi.json http://localhost:8080/v3/api-docs

# Stop the server
kill $SERVER_PID

# Generate TypeScript client using npx
echo "Generating TypeScript client..."
npx @openapitools/openapi-generator-cli generate \
  -i client/openapi.json \
  -g typescript-fetch \
  -o client/typescript \
  --additional-properties=npmName=drimain-api-client,typescriptThreePlus=true

echo "TypeScript client generated in client/typescript/"
echo "OpenAPI spec saved as client/openapi.json"

# Create package-lock.json in client directory
cd client/typescript
npm install
cd ../..

echo "Client generation complete!"