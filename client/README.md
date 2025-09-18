# DriMain API Client

This directory contains the TypeScript client generated from the OpenAPI specification.

## Files

- `openapi.json` - The OpenAPI specification exported from the running application
- `package.json` - Package configuration for TypeScript client
- `package-lock.json` - Lockfile for reproducible builds
- `generate-client.sh` - Script to regenerate the client from OpenAPI spec

## Generation Process

The client is generated from the live application's OpenAPI specification using the following process:

1. Start the Spring Boot application
2. Export the OpenAPI spec from `/v3/api-docs`
3. Use OpenAPI Generator to create TypeScript client
4. Install dependencies and create package-lock.json

## API Changes

The Zgloszenie entity has been enhanced with:
- New fields: `tytul`, `createdAt`, `updatedAt`
- Relations: `dzialId`, `dzialNazwa`, `autorId`, `autorUsername`
- All existing fields preserved for backward compatibility
- Proper enum handling for `ZgloszenieStatus`

## Security

- ROLE_BIURO has same edit/delete permissions as ROLE_ADMIN
- Authentication required for all API endpoints
- JWT token-based authentication