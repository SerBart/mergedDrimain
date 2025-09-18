# PR3 - Server-Sent Events (SSE) + Domain Events

## Overview

Real-time event streaming system using Server-Sent Events (SSE) for broadcasting changes to zgloszenia and attachments.

## Architecture

### Domain Events
- **EventType** enum: `CREATED`, `UPDATED`, `DELETED`, `ATTACHMENT_ADDED`, `ATTACHMENT_REMOVED`
- **ZgloszenieDomainEvent**: Application event carrying event data
- **ZgloszenieCommandService**: Publishes events for all mutations
- **AttachmentService**: Publishes attachment-related events

### SSE Service
- **SseSubscriptionService**: Manages client subscriptions and event distribution
- Client subscription limits (100 by default)
- Automatic cleanup of failed/timed-out connections
- Event filtering by type
- Heartbeat mechanism (every 30 seconds)

## SSE Endpoint

### Subscribe to Events
```
GET /api/zgloszenia/stream
Headers: Authorization: Bearer {token}

Query Parameters:
- types: Comma-separated event types (optional)
  - Example: types=CREATED,UPDATED
  - Available: CREATED, UPDATED, DELETED, ATTACHMENT_ADDED, ATTACHMENT_REMOVED
- dzialId: Filter by department ID (TODO - not implemented)
- autorId: Filter by author ID (TODO - not implemented)  
- full: Include full entity snapshots (TODO - not implemented)
```

### Event Format
```
event: CREATED
data: {
  "type": "CREATED",
  "zgloszenieId": 123,
  "eventTimestamp": "2025-09-01T10:30:00",
  "changedFields": null,
  "attachmentId": null
}
```

```
event: UPDATED
data: {
  "type": "UPDATED", 
  "zgloszenieId": 123,
  "eventTimestamp": "2025-09-01T10:35:00",
  "changedFields": ["status", "opis"],
  "attachmentId": null
}
```

```
event: ATTACHMENT_ADDED
data: {
  "type": "ATTACHMENT_ADDED",
  "zgloszenieId": 123,
  "eventTimestamp": "2025-09-01T10:40:00",
  "changedFields": null,
  "attachmentId": 456
}
```

### Monitoring Endpoint
```
GET /api/zgloszenia/stream/status
Response: {
  "activeSubscriptions": 5,
  "status": "SSE service running"
}
```

## Event Flow

1. **CREATED**: When new zgloszenie is created via POST /api/zgloszenia
2. **UPDATED**: When zgloszenie is modified via PUT /api/zgloszenia/{id}
   - Includes `changedFields` array with modified field names
3. **DELETED**: When zgloszenie is deleted via DELETE /api/zgloszenia/{id}
4. **ATTACHMENT_ADDED**: When file is uploaded via POST /api/zgloszenia/{id}/attachments
5. **ATTACHMENT_REMOVED**: When attachment is deleted via DELETE /api/attachments/{id}

## Configuration

Add to `application.properties`:

```properties
# SSE Configuration
app.sse.max-clients=100
app.sse.heartbeat-interval-seconds=30
app.sse.client-timeout-seconds=300
```

## Client Implementation Example

```javascript
const eventSource = new EventSource('/api/zgloszenia/stream?types=CREATED,UPDATED', {
    headers: {
        'Authorization': 'Bearer ' + token
    }
});

eventSource.addEventListener('CREATED', function(event) {
    const data = JSON.parse(event.data);
    console.log('New zgloszenie:', data.zgloszenieId);
});

eventSource.addEventListener('UPDATED', function(event) {
    const data = JSON.parse(event.data);
    console.log('Updated fields:', data.changedFields);
});

eventSource.addEventListener('HEARTBEAT', function(event) {
    console.log('Connection alive');
});

eventSource.onerror = function(event) {
    console.error('SSE error:', event);
};
```

## Features

### Automatic Cleanup
- Dead connections are automatically removed
- Heartbeat mechanism detects failed clients
- Connection timeouts (5 minutes by default)

### Event Filtering  
- Filter by event types using query parameter
- Future: Filter by dzialId/autorId (requires entity snapshots)

### Scalability
- Configurable client limits
- Parallel event distribution
- Efficient connection management

## Security

- Requires JWT authentication
- Events contain minimal data for security
- No sensitive information in event payload
- TODO: Role-based access control for events

## TODO / Future Enhancements

- **Entity Snapshots**: Include full entity data for filtering by dzialId/autorId
- **Last-Event-ID**: Support event replay from specific point
- **Persistent Events**: Store events for offline clients
- **Role-based Filtering**: Filter events based on user roles
- **Event Backlog**: Replay missed events on reconnection