# PR2 - Attachments System

## Overview

Comprehensive file attachment system for zgloszenia (issues) with file upload, download, and deletion capabilities.

## Features

### File Storage
- Configurable storage directory (`uploads/attachments` by default)
- Unique filename generation to prevent conflicts
- File size validation (10MB max by default)
- Content type validation (images, PDFs, Office docs, text files, archives)
- Optional checksum calculation (SHA-256)

### Attachment Entity
- **Attachment** entity with fields:
  - Original filename preservation
  - Content type and file size tracking
  - Creation timestamp and creator tracking
  - Relationship to Zgloszenie (OneToMany with orphanRemoval)

### REST API Endpoints

#### Upload Attachments
```
POST /api/zgloszenia/{id}/attachments
Content-Type: multipart/form-data

Form fields:
- files: List<MultipartFile>

Response: AttachmentUploadResponse with list of AttachmentDTO
```

#### List Attachments
```
GET /api/zgloszenia/{id}/attachments
Response: List<AttachmentDTO>
```

#### Download Attachment
```
GET /api/attachments/{attachmentId}/download
Response: File stream with proper content-type and filename headers
```

#### Delete Attachment
```
DELETE /api/attachments/{attachmentId}
Response: 204 No Content
```

## Configuration

Add to `application.properties`:

```properties
# Attachment Storage Configuration
app.attachments.base-path=uploads/attachments
app.attachments.max-file-size-bytes=10485760
```

## Security

- All attachment endpoints require authentication
- File type validation prevents malicious uploads
- Files are stored outside web root for security
- Original filenames are preserved but files are stored with UUIDs

## Integration

- Attachments are automatically deleted when parent Zgloszenie is deleted (orphanRemoval)
- Events are published for attachment operations (see PR3 - SSE Events)
- Attachment operations are logged for auditing