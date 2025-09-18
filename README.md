"# DriMain - Unified Web & Mobile Application

DriMain is a comprehensive maintenance management system with both web UI and mobile app support. This monorepo contains:

- **Backend**: Spring Boot REST API with JWT authentication (Java 17)
- **Frontend**: Flutter web and mobile application
- **Database**: H2 (development) / PostgreSQL (production)

## 🏗️ Monorepo Structure

```
├── src/main/java/               # Spring Boot backend source
├── src/main/resources/          # Backend resources and static assets
├── frontend/                    # Flutter application
│   ├── lib/                    # Flutter source code
│   ├── web/                    # Web-specific platform files
│   ├── android/                # Android platform files
│   ├── ios/                    # iOS platform files
│   └── pubspec.yaml           # Flutter dependencies
├── build-frontend.sh           # Frontend build script
└── pom.xml                     # Maven configuration
```

## 🚀 Development Workflow

### Prerequisites

- Java 17
- Flutter 3.0+ (stable)
- Maven (via `./mvnw`)

### Backend Development

1. **Start the backend**:
   ```bash
   ./mvnw spring-boot:run
   ```
   - Runs on http://localhost:8080
   - H2 Console: http://localhost:8080/h2-console
   - API Documentation: http://localhost:8080/swagger-ui/index.html

2. **Test the backend**:
   ```bash
   ./mvnw test
   ```

### Frontend Development

1. **Install dependencies**:
   ```bash
   cd frontend
   flutter pub get
   ```

2. **Run Flutter in development**:
   ```bash
   cd frontend
   flutter run -d web --dart-define=API_BASE=http://localhost:8080
   ```

3. **Build for production**:
   ```bash
   ./build-frontend.sh
   ```

### Full Production Build

```bash
# Build Flutter web and integrate with Spring Boot
./build-frontend.sh

# Build the complete application
./mvnw clean package

# Run the integrated application
java -jar target/driMain-1.0.0.jar
```

## 🔐 Authentication & Security

- **JWT-based authentication** for both web and mobile
- **Stateless REST API** with Bearer token authentication
- **Default test accounts**:
  - Admin: `admin` / `admin123` (ROLE_ADMIN, ROLE_USER)
  - User: `user` / `user123` (ROLE_USER)

### API Authentication

```bash
# Login
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

# Use the returned token
curl -H "Authorization: Bearer <token>" \
  http://localhost:8080/api/zgloszenia
```

### 🔄 Refresh Token Flow

DriMain now supports secure refresh token authentication:

- **Access tokens**: Short-lived (1 hour) for API access
- **Refresh tokens**: Long-lived (7 days) for token renewal
- **Automatic token management**: Refresh before expiration

```bash
# Login returns both tokens
{
  "token": "eyJ0eXAiOiJKV1QiLCJhbGc...",      # Access token
  "refreshToken": "550e8400-e29b-41d4-a716..." # Refresh token
}

# Refresh access token
curl -X POST http://localhost:8080/api/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{"refreshToken":"550e8400-e29b-41d4-a716..."}'

# Get current user info
curl -H "Authorization: Bearer <token>" \
  http://localhost:8080/api/users/me
```

### 👥 Roles and Permissions

DriMain implements role-based access control:

- **ROLE_USER**: Can read reports and access basic endpoints
- **ROLE_ADMIN**: Can create, update, and delete reports
- **ROLE_MAGAZYN**: Warehouse-specific operations
- **ROLE_BIURO**: Office-specific operations

**Report Management Access:**
- `GET /api/raporty` - All authenticated users
- `POST /api/raporty` - ADMIN only
- `PUT /api/raporty/{id}` - ADMIN only  
- `DELETE /api/raporty/{id}` - ADMIN only

### 📊 Audit Logging

All report operations are automatically audited:

- **Report Creation**: Tracks who created each report (`createdBy` field)
- **Operation Logging**: Logs all CRUD operations with user information
- **Security Events**: Logs authentication and authorization events

Example audit log entries:
```
INFO - Report created by user: admin
INFO - Report 123 updated by user: admin
INFO - Report 456 deleted by user: admin
```

## 📱 Mobile & Web Support

The Flutter frontend supports:
- **Web browsers** (primary deployment target)
- **iOS** mobile applications
- **Android** mobile applications
- **Desktop** (Linux, macOS, Windows) 

All platforms share the same codebase and connect to the unified REST API.

## 🛠️ REST API Endpoints

### Authentication
- `POST /api/auth/login` - User login
- `GET /api/auth/me` - Current user info

### Core Features
- `GET|POST|PUT|DELETE /api/zgloszenia` - Issue management
- `GET|POST|PUT|DELETE /api/harmonogramy` - Schedule management  
- `GET|POST|PUT|DELETE /api/czesci` - Parts management
- `GET|POST|PUT|DELETE /api/raporty` - Reports management

### Admin Functions (ROLE_ADMIN required)
- `/api/admin/dzialy` - Department management
- `/api/admin/maszyny` - Machine management
- `/api/admin/osoby` - Personnel management
- `/api/admin/users` - User account management

## 🗄️ Database Configuration

### Flyway Database Migrations

DriMain now uses Flyway for database schema management:

- **Automatic migrations**: Database schema is version-controlled
- **Production safety**: Schema changes tracked and validated
- **Migration files**: Located in `src/main/resources/db/migration/`

```properties
# Flyway configuration (application.properties)
spring.flyway.enabled=true
spring.flyway.locations=classpath:db/migration
spring.flyway.baseline-on-migrate=true
spring.jpa.hibernate.ddl-auto=validate  # Changed from 'update' to 'validate'
```

**Migration History:**
- `V1__initial_schema.sql` - Base tables (users, roles, reports, etc.)
- `V2__add_refresh_tokens_and_audit.sql` - Refresh tokens and audit fields

### Development (H2)
```properties
# src/main/resources/application.properties
spring.datasource.url=jdbc:h2:mem:testdb
spring.datasource.username=sa
spring.datasource.password=
```

### Production (PostgreSQL)
```yaml
# src/main/resources/application.yml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/drimain
    username: drimain
    password: drimain
```

### Environment Variables

Use `.env.example` as a template for environment configuration:
```bash
cp .env.example .env
# Edit .env with your production values
```

## 🔧 JWT Configuration

Enhanced JWT settings with refresh token support:

```yaml
# src/main/resources/application.yml
app:
  jwt:
    secret: "REPLACE_WITH_STRONG_SECRET_AT_LEAST_32_CHARS_LONG_1234567890"
    ttl-seconds: 3600                # Legacy setting (1 hour)
    access-expiration: 3600000       # Access token: 1 hour (in milliseconds)
    refresh-expiration: 604800000    # Refresh token: 7 days (in milliseconds)
```

```properties
# Alternative configuration in application.properties
app.jwt.secret=REPLACE_WITH_STRONG_SECRET_AT_LEAST_32_CHARS_LONG_1234567890
app.jwt.access-expiration=3600000
app.jwt.refresh-expiration=604800000
```

### Token Lifecycle

- **Access Token**: Used for API authentication (1 hour lifespan)
- **Refresh Token**: Used to obtain new access tokens (7 days lifespan)
- **Automatic Cleanup**: Expired refresh tokens are automatically cleaned up
- **Security**: Refresh tokens are revoked on logout (planned feature)

**⚠️ Important**: Change the JWT secret for production deployment!

## 🔄 CI/CD Pipeline

Enhanced GitHub Actions workflow (`.github/workflows/ci.yml`):

### Backend Testing & Building
- ✅ **Comprehensive Testing**: Maven `verify` with integration tests
- ✅ **Security Testing**: Role-based access control validation
- ✅ **Refresh Token Testing**: Complete authentication flow testing
- ✅ **Test Artifacts**: Automatic upload of test results on failure
- ✅ **Maven Caching**: Optimized dependency caching

### Frontend Testing & Integration  
- ✅ **Flutter Analysis**: Code quality and linting
- ✅ **Flutter Testing**: Unit and widget tests
- ✅ **Integration Build**: Flutter web → Spring Boot static resources
- ✅ **Artifact Upload**: JAR file and build assets
- ✅ **Flutter Caching**: Pub cache optimization

### Pipeline Features
- 🔄 **Multi-job workflow**: Backend, frontend, and integration builds
- 📦 **Artifact management**: Automatic build artifact collection
- ⚡ **Smart caching**: Maven and Flutter dependency caching
- 🚨 **Failure handling**: Test result collection and reporting

## 🧪 Testing

### Running Tests

```bash
# Run all tests (unit + integration)
./mvnw test

# Run tests with coverage
./mvnw verify

# Run specific test class
./mvnw test -Dtest=RefreshTokenIntegrationTest

# Run specific test method  
./mvnw test -Dtest=AdminSecurityIntegrationTest#shouldAllowAdminToCreateReport
```

### Test Categories

**Unit Tests:**
- JwtService functionality
- Service layer logic
- Repository operations

**Integration Tests:**
- Complete authentication flows
- Role-based access control
- Refresh token mechanisms
- Admin security restrictions
- API endpoint validation

### Test Configuration

Tests use H2 in-memory database with dedicated test profile:
- Profile: `test` 
- Database: H2 (in-memory)
- JWT: Test configuration with shorter expiration
- Flyway: Disabled (uses JPA DDL)

### Comprehensive Test Examples

See `docs/curl-examples.sh` for complete API testing examples including:
- Login and token management
- Refresh token flow
- Role-based endpoint access
- User information retrieval

## 🌐 CORS Configuration

Development origins are pre-configured in `CorsConfig.java`:
- `http://localhost:3000` - Flutter web dev
- `http://localhost:5173` - Vite dev server
- `http://10.0.2.2:8080` - Android emulator

**📝 TODO**: Restrict CORS origins for production deployment.

## 🚧 Migration Status & Features

### ✅ Completed Features

**Core Infrastructure:**
- ✅ **REST API Infrastructure** - Complete with comprehensive endpoints
- ✅ **JWT Authentication** - Enhanced with refresh token support  
- ✅ **Flutter Foundation** - Complete frontend architecture
- ✅ **CI/CD Pipeline** - Enhanced with comprehensive testing

**Security & Authentication:**
- ✅ **Refresh Token Flow** - Secure token management with rotation
- ✅ **Role-Based Access Control** - Admin restrictions for report management
- ✅ **Method-Level Security** - @PreAuthorize annotations implemented
- ✅ **User Info Endpoint** - `/api/users/me` with role information

**Database & Migrations:**
- ✅ **Flyway Integration** - Database schema version control
- ✅ **Audit Logging** - Report creation tracking with user information
- ✅ **Migration Scripts** - V1 (baseline) + V2 (refresh tokens & audit)

**Testing & Quality:**
- ✅ **Integration Tests** - Complete authentication and security flow testing
- ✅ **Test Environment** - Dedicated test profile with H2 database
- ✅ **CI Testing** - Automated test execution with artifact collection
- ✅ **API Examples** - Comprehensive curl examples in `docs/curl-examples.sh`

**Configuration & Documentation:**
- ✅ **Environment Templates** - `.env.example` with all required variables
- ✅ **Enhanced Exception Handling** - Validation error responses
- ✅ **Swagger Integration** - API documentation with redirect controller
- ✅ **CORS Configuration** - Development-ready with production TODOs

### 🔄 In Progress
- 🔄 **Feature Migration** - Continued frontend component development
- 🔄 **Advanced Security** - Logout endpoint and token rotation (TODO comments added)

### ⏳ Planned
- ⏳ **Legacy UI Removal** - Phase out Thymeleaf templates
- ⏳ **Rate Limiting** - API endpoint protection
- ⏳ **Advanced Monitoring** - Application metrics and health checks

## 📚 Additional Resources

- **Spring Boot Documentation**: https://spring.io/projects/spring-boot
- **Flutter Documentation**: https://flutter.dev/docs
- **JWT.io**: https://jwt.io/
- **H2 Database Console**: http://localhost:8080/h2-console (when running)
- **OpenAPI/Swagger UI**: http://localhost:8080/swagger-ui/index.html" 
