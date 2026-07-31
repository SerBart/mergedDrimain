# DriMain - Security Best Practices & Configuration

This guide documents security configurations and best practices implemented in DriMain.

## 🔒 Security Features Checklist

### Authentication & Authorization
- ✅ JWT-based stateless authentication
- ✅ Refresh token mechanism with expiration
- ✅ Role-based access control (RBAC)
- ✅ Method-level security with @PreAuthorize
- ✅ Module-level permissions with ModuleGuard

### Input Validation
- ✅ DTO-level validation with Jakarta Validation
- ✅ Email format validation (RFC 5322)
- ✅ Password complexity enforcement
- ✅ String length constraints
- ✅ Numeric range validation
- ✅ File upload validation (MIME type, magic bytes, size)

### File Security
- ✅ Path traversal prevention
- ✅ File extension validation
- ✅ MIME type validation
- ✅ Magic bytes verification
- ✅ SHA-256 checksum calculation
- ✅ Secure filename generation (UUID)

### HTTP Security
- ✅ CSRF disabled for stateless API
- ✅ CORS configured with whitelist
- ✅ Secure headers (X-Content-Type-Options, X-Frame-Options, etc.)
- ✅ HSTS support (configurable)
- ✅ Content Security Policy headers

### Data Protection
- ✅ Password hashing with BCrypt
- ✅ Sensitive data not logged
- ✅ Email normalization (lowercase)
- ✅ Transactional integrity
- ✅ Foreign key constraints

### Rate Limiting
- ✅ IP-based rate limiting (100 req/min default)
- ✅ Configurable per-endpoint limits
- ✅ Automatic cleanup of old entries
- ✅ Custom Retry-After headers

---

## 🔐 Configuration Guide

### JWT Secret Generation

**Generate strong JWT secret (minimum 32 characters):**

```bash
# Using OpenSSL
openssl rand -base64 32

# Using Java
java -jar target/driMain-1.0.0.jar --generate-secret

# Example output
XyZaBcDeFgHiJkLmNoPqRsTuVwXyZaBcD==
```

**Set in environment:**
```bash
export APP_JWT_SECRET="XyZaBcDeFgHiJkLmNoPqRsTuVwXyZaBcD=="
```

### Application Configuration

**application.yml - Security Settings:**
```yaml
spring:
  security:
    user:
      name: admin
      password: admin123

app:
  security:
    h2-console-enabled: false  # Disable in production
    swagger-enabled: true
    hsts-enabled: true         # Enable HSTS in production
    csp: "default-src 'self' https:; script-src 'self'; style-src 'self' 'unsafe-inline';"
  
  jwt:
    secret: ${APP_JWT_SECRET:change-me-in-production}
    expiration: 3600           # 1 hour in seconds
    refresh-expiration: 604800 # 7 days in seconds
  
  cors:
    allowed-origins: http://localhost:3000, https://yourdomain.com
    allowed-methods: GET,POST,PUT,DELETE,OPTIONS
    allowed-headers: Content-Type,Authorization
    max-age: 3600
    allow-credentials: true
  
  attachments:
    base-path: /app/uploads/attachments
    max-file-size-bytes: 10485760  # 10MB
    allowed-content-types:
      - image/png
      - image/jpeg
      - image/gif
      - application/pdf
```

---

## 🚨 Security Threats & Mitigations

### 1. **SQL Injection**
**Threat**: Malicious SQL execution
**Mitigation**: 
- Using Spring Data JPA (parameterized queries)
- Never concatenate user input in queries
- Use Repository query methods or @Query with parameters

```java
// ❌ VULNERABLE
Query query = em.createQuery("SELECT u FROM User u WHERE username = '" + username + "'");

// ✅ SAFE
@Query("SELECT u FROM User u WHERE u.username = ?1")
Optional<User> findByUsername(String username);
```

### 2. **XSS (Cross-Site Scripting)**
**Threat**: Injection of malicious JavaScript
**Mitigation**:
- Content Security Policy headers
- Input validation (no script tags in text fields)
- Output encoding at frontend

```java
// DTO validation prevents script tags
@NotBlank
@Size(min = 1, max = 255)
private String tytul; // Frontend must encode on display
```

### 3. **CSRF (Cross-Site Request Forgery)**
**Threat**: Forged requests from other sites
**Mitigation**:
- CSRF disabled for stateless API (JWT-protected)
- SameSite cookies enabled

### 4. **Path Traversal**
**Threat**: Access files outside intended directory
**Mitigation**:
```java
// Validate filename doesn't contain path separators
if (filename.contains("..") || filename.contains("/") || filename.contains("\\")) {
    throw new SecurityException("Invalid filename");
}

// Verify resolved path is within storage directory
Path realPath = filePath.toRealPath();
if (!realPath.startsWith(storageDir.toRealPath())) {
    throw new SecurityException("Path traversal attempt");
}
```

### 5. **Weak Authentication**
**Threat**: Easily guessable credentials
**Mitigation**:
- Password complexity requirements enforced
- BCrypt password hashing (work factor 10)
- Account lockout on failed attempts (future)

```java
// Password pattern enforced in DTO
@Pattern(regexp = "^(?=.*[A-Z])(?=.*[a-z])(?=.*\\d)(?=.*[@$!%*?&])[A-Za-z\\d@$!%*?&]{8,}$")
private String password;
```

### 6. **Sensitive Data Exposure**
**Threat**: Leaking passwords, tokens, or PII
**Mitigation**:
- Tokens in secure HTTP-only cookies
- Passwords never logged
- Errors don't expose implementation details
- HTTPS enforced in production

```java
// Logging example - no sensitive data
log.info("User {} login successful", username); // ✅ OK
log.info("User {} password: {}", username, password); // ❌ NEVER!
```

### 7. **Broken Access Control**
**Threat**: Users accessing data they shouldn't
**Mitigation**:
- Role-based access control (RBAC)
- Module-level permissions
- Method-level security checks
- Department-based filtering

```java
@PreAuthorize("@moduleGuard.has('Zgloszenia')") // Check module access
public List<ZgloszenieDTO> list() {
    // Further filter by department
    if (!isAdmin(auth)) {
        all = filterByUserDepartment(all, auth);
    }
    return all;
}
```

### 8. **Using Components with Known Vulnerabilities**
**Threat**: Security vulnerabilities in dependencies
**Mitigation**:
- Regular dependency updates
- CVE scanning in CI/CD
- Maven dependency check plugin

```bash
# Check for vulnerabilities
./mvnw dependency-check:check

# Update dependencies
./mvnw versions:display-plugin-updates
./mvnw versions:display-property-updates
```

### 9. **Insufficient Logging & Monitoring**
**Threat**: Can't detect or investigate attacks
**Mitigation**:
- Comprehensive logging at all layers
- Log failed authentication attempts
- Log access to sensitive data
- Centralized log aggregation

```java
log.warn("Failed login attempt for user: {}", username);
log.info("User {} accessed sensitive report: {}", user, reportId);
log.error("Unauthorized access attempt for resource: {}", resourceId);
```

### 10. **Insecure Deserialization**
**Threat**: Malicious object deserialization
**Mitigation**:
- Only deserialize trusted data
- Use DTOs with validation
- No direct deserialization of user input

```java
// ✅ SAFE - Input validated in DTO
@PostMapping
public ResponseEntity<?> create(@Valid @RequestBody ZgloszenieCreateRequest req) {
    // req is already validated before reaching this point
}

// ❌ NEVER do this
ObjectInputStream ois = new ObjectInputStream(userSuppliedStream);
Object obj = ois.readObject(); // Dangerous!
```

---

## 🛡️ Secure Coding Practices

### 1. Input Validation
```java
// ✅ Always validate at entry points
@PostMapping
public ResponseEntity<?> create(@Valid @RequestBody CreateRequest req) {
    // JSR-303 validation already passed
    // Additional business logic validation:
    if (req.getStartDate().isAfter(req.getEndDate())) {
        throw new IllegalArgumentException("Start date must be before end date");
    }
}
```

### 2. Error Messages
```java
// ❌ Too much detail
throw new RuntimeException("User not found: SELECT * FROM users WHERE id=123 returned null");

// ✅ Generic but helpful
throw new IllegalArgumentException("User not found");
```

### 3. Logging Sensitive Data
```java
// ❌ Never log these
log.info("User {} password: {}", user, password);
log.info("Card number: {}", cardNumber);
log.info("SSN: {}", ssn);

// ✅ Safe logging
log.info("User {} updated profile", username);
log.info("Payment processed for user: {}", maskedCardNumber("****1234"));
```

### 4. Exception Handling
```java
// ❌ Catch-all that hides errors
try {
    // code
} catch (Exception e) {
    return ResponseEntity.ok("OK"); // Problem hidden!
}

// ✅ Specific exception handling
try {
    // code
} catch (DataIntegrityViolationException e) {
    log.warn("Duplicate entry attempted: {}", e.getMessage());
    return ResponseEntity.status(409).body("Record already exists");
} catch (IOException e) {
    log.error("File operation failed", e);
    return ResponseEntity.status(500).body("Internal server error");
}
```

### 5. Safe File Operations
```java
// ✅ Safe file handling
private String generateSafeFilename() {
    return UUID.randomUUID().toString() + getFileExtension(original);
}

private void validateFile(MultipartFile file) {
    if (file.getSize() > MAX_SIZE) throw new IllegalArgumentException("File too large");
    
    String contentType = file.getContentType();
    if (!ALLOWED_TYPES.contains(contentType)) {
        throw new IllegalArgumentException("File type not allowed");
    }
    
    byte[] bytes = file.getBytes();
    if (!hasValidMagicBytes(bytes)) {
        throw new IllegalArgumentException("Invalid file format");
    }
}
```

---

## 🔍 Security Testing

### Manual Testing Checklist

```bash
# 1. Test authentication
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

# 2. Test authorization (without token)
curl http://localhost:8080/api/zgloszenia
# Should return 401 Unauthorized

# 3. Test with invalid token
curl -H "Authorization: Bearer invalid" \
  http://localhost:8080/api/zgloszenia
# Should return 401 Unauthorized

# 4. Test CORS preflight
curl -X OPTIONS http://localhost:8080/api/zgloszenia \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: POST"

# 5. Test rate limiting
for i in {1..110}; do
  curl http://localhost:8080/api/parts
done
# 11th request onwards should return 429 Too Many Requests

# 6. Test file upload with path traversal
curl -F "file=@../../etc/passwd" \
  http://localhost:8080/api/zgloszenia/1/attachments
# Should be rejected

# 7. Test input validation
curl -X POST http://localhost:8080/api/zgloszenia \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"typ":"","opis":"short"}' # Invalid
# Should return 400 with validation errors
```

### Automated Security Testing

```bash
# OWASP Dependency Check
./mvnw dependency-check:check

# SonarQube analysis
./mvnw sonar:sonar \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.login=$SONAR_TOKEN

# Spring Security test suite
mvn test -Dtest=SecurityTest*
```

---

## 📋 Production Deployment Security Checklist

- [ ] JWT_SECRET set to strong value (minimum 32 chars)
- [ ] Database password encrypted in transit (SSL)
- [ ] H2 console disabled
- [ ] Swagger disabled (or password-protected)
- [ ] HSTS enabled
- [ ] CORS configured for specific domains only
- [ ] Application logs not exposing sensitive data
- [ ] SSL/TLS certificate valid and up-to-date
- [ ] Security headers configured
- [ ] Rate limiting active
- [ ] Database backups encrypted
- [ ] Access logs enabled
- [ ] Monitoring/alerting configured
- [ ] Dependency vulnerabilities scanned
- [ ] Code review completed
- [ ] Security testing completed
- [ ] Firewall rules configured
- [ ] Database connection pooling limits set
- [ ] File upload directory protected
- [ ] Admin credentials changed from defaults

---

## 🚀 Security Hardening for Production

### Environment Variables (Required)

```bash
# Absolutely required - change immediately
APP_JWT_SECRET=<generate-new-strong-secret>
SPRING_DATASOURCE_PASSWORD=<strong-db-password>

# Highly recommended
SPRING_PROFILES_ACTIVE=prod
SERVER_SSL_ENABLED=true
SERVER_SSL_KEY_STORE=/path/to/keystore.jks
SERVER_SSL_KEY_STORE_PASSWORD=<keystore-password>
SERVER_SSL_KEY_STORE_TYPE=JKS
SERVER_SSL_KEY_ALIAS=tomcat
```

### Additional Security Headers

Add to application.yml:
```yaml
server:
  servlet:
    session:
      cookie:
        http-only: true
        secure: true
        same-site: strict
  error:
    include-stacktrace: never  # Don't expose stack traces
```

---

## 📞 Security Contact & Reporting

For security vulnerabilities, please email: security@drimain.com

Do not disclose vulnerabilities publicly. We follow responsible disclosure practices.

---

**Version**: 1.0.0  
**Last Updated**: 2026-07-31  
**Status**: Production Ready

