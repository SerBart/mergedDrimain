"# DriMain - Unified Web & Mobile Application

DriMain is a comprehensive maintenance management system with both web UI and mobile app support. This monorepo contains:

- **Backend**: Spring Boot REST API with JWT authentication (Java 17)
- **Frontend**: Flutter web and mobile application
- **Database**: H2 (development) / PostgreSQL (production)

## 🚀 Quick Start (TL;DR)

For non-technical users - 5 steps to get DriMain running locally:

1. **Prerequisites**: Install Docker and Docker Compose
2. **Clone & Navigate**: `git clone <repo-url> && cd mergedDrimain`
3. **Start with Docker**: `docker compose up --build`
4. **Access Application**: Open http://localhost:8080 in your browser
5. **Login**: Use `admin`/`admin123` or `user`/`user123`

**That's it!** 🎉 The application will be running with a PostgreSQL database.

---

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
- Docker & Docker Compose (for production-like setup)

### Local Development Options

#### Option 1: Docker Compose (Recommended)

**Quick production-like setup with PostgreSQL:**

```bash
# Start everything with Docker
docker compose up --build

# Access the application
open http://localhost:8080
```

This will start both the Spring Boot app and PostgreSQL database.

#### Option 2: Development Mode (H2 Database)

**For backend development with in-memory database:**

```bash
# Start the backend
./mvnw spring-boot:run

# Application will be available at:
# - Main app: http://localhost:8080
# - H2 Console: http://localhost:8080/h2-console
# - API docs: http://localhost:8080/swagger-ui/index.html
# - Health check: http://localhost:8080/actuator/health
```

**H2 Console Access:**
- URL: `jdbc:h2:mem:testdb`
- Username: `sa`
- Password: (empty)

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

3. **Build for production**:
   ```bash
   ./mvnw clean package
   ```

### PostgreSQL Configuration

#### Local PostgreSQL Setup

1. **Install PostgreSQL** (or use Docker):
   ```bash
   # Using Docker
   docker run --name drimain-postgres -e POSTGRES_DB=drimain -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -p 5432:5432 -d postgres:15
   ```

2. **Configure database connection** in `application.properties`:
   ```properties
   spring.datasource.url=jdbc:postgresql://localhost:5432/drimain
   spring.datasource.username=postgres
   spring.datasource.password=postgres
   ```

#### DBeaver Setup & Password Reset

1. **Download DBeaver**: https://dbeaver.io/download/
2. **Create connection**:
   - Host: `localhost`
   - Port: `5432`
   - Database: `drimain`
   - Username: `postgres`
   - Password: `postgres`

3. **Reset PostgreSQL password** (if needed):
   ```bash
   # Connect to PostgreSQL container
   docker exec -it drimain-postgres psql -U postgres
   
   # Reset password
   ALTER USER postgres PASSWORD 'postgres';
   ```

### Frontend Development

1. **Install dependencies**:
   ```bash
   cd frontend
   flutter pub get
   ```

2. **Run Flutter for different platforms**:

   **Web (connects to localhost:8080):**
   ```bash
   cd frontend
   flutter run -d web --dart-define=API_BASE=http://localhost:8080
   ```

   **Android Emulator (uses special IP):**
   ```bash
   cd frontend
   flutter run -d android --dart-define=API_BASE=http://10.0.2.2:8080
   ```

   **iOS Simulator:**
   ```bash
   cd frontend
   flutter run -d ios --dart-define=API_BASE=http://localhost:8080
   ```

   **Physical device (replace with your IP):**
   ```bash
   cd frontend
   flutter run -d device --dart-define=API_BASE=http://192.168.1.100:8080
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

---

## 🔑 Key API Endpoints

### Authentication
- `POST /api/auth/login` - User login (returns JWT token)
- `GET /api/auth/me` - Current user information

### Core Features
- `GET|POST|PUT|DELETE /api/raporty` - **Reports management**
- `GET|POST|PUT|DELETE /api/zgloszenia` - **Issues management**
- `GET|POST|PUT|DELETE /api/czesci` - **Parts/inventory management**
- `GET|POST|PUT|DELETE /api/harmonogramy` - **Schedule management**

### Admin Functions (ROLE_ADMIN required)
- `/api/admin/users` - **User account management**
- `/api/admin/dzialy` - **Department management**
- `/api/admin/maszyny` - **Machine management**
- `/api/admin/osoby` - **Personnel management**

### System Endpoints
- `/actuator/health` - **Health check**
- `/swagger-ui/index.html` - **API documentation**
- `/v3/api-docs` - **OpenAPI specification**

---

## 🧪 API Testing with cURL

### Quick Test Script

Run the provided test script for comprehensive API testing:

```bash
chmod +x docs/curl-examples.sh
./docs/curl-examples.sh
```

### Manual cURL Examples

**1. Login and get token:**
```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
```

**2. Use token to access protected endpoints:**
```bash
# Replace YOUR_TOKEN with the token from login response
TOKEN="your_jwt_token_here"

# Get reports
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8080/api/raporty

# Create new report
curl -X POST http://localhost:8080/api/raporty \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "opis": "Test report",
    "status": "NOWY",
    "dataNaprawy": "2024-01-15",
    "maszynaId": 1
  }'

# Get parts inventory
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8080/api/czesci
```

**3. Health check (no auth required):**
```bash
curl http://localhost:8080/actuator/health
```

---

## 🔧 Flutter Integration Setup

### API Base Configuration

The Flutter app needs to know where to find the backend API. Use the `API_BASE` environment variable:

**For Web Development:**
- Backend on localhost: `--dart-define=API_BASE=http://localhost:8080`

**For Android Emulator:**
- Use special IP: `--dart-define=API_BASE=http://10.0.2.2:8080`
- `10.0.2.2` maps to host machine's `127.0.0.1`

**For Production:**
- Set your domain: `--dart-define=API_BASE=https://your-domain.com`

### Example Flutter Code

```dart
const String apiBase = String.fromEnvironment('API_BASE', 
    defaultValue: 'http://localhost:8080');

// Store JWT token
await SharedPreferences.getInstance()
    .then((prefs) => prefs.setString('jwt_token', token));

// Make authenticated request
final response = await http.get(
  Uri.parse('$apiBase/api/raporty'),
  headers: {'Authorization': 'Bearer $token'},
);
```

See [docs/flutter-config.md](docs/flutter-config.md) for complete integration guide.

---

## 🔐 Authentication & Security

- **JWT-based authentication** for both web and mobile
- **Stateless REST API** with Bearer token authentication
- **Default test accounts**:
  - Admin: `admin` / `admin123` (ROLE_ADMIN, ROLE_USER)
  - User: `user` / `user123` (ROLE_USER)

### JWT Configuration & Security Notes

**Current JWT settings** (in `application.yml`):
```yaml
app:
  jwt:
    secret: "REPLACE_WITH_STRONG_SECRET_AT_LEAST_32_CHARS_LONG_1234567890"
    ttl-seconds: 3600  # 1 hour
```

**⚠️ Important Security Notes:**
- Change the JWT secret for production deployment!
- Token expires after 1 hour (3600 seconds)
- **TODO**: Implement refresh token mechanism
- **TODO**: Add proper UserDetailsService integration
- No refresh token implemented yet - users must re-login after expiration

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

---

## 🗄️ Database Configuration

### Development (H2 - In Memory)
```properties
# src/main/resources/application.properties
spring.datasource.url=jdbc:h2:mem:testdb
spring.datasource.username=sa
spring.datasource.password=
```

**Access H2 Console:** http://localhost:8080/h2-console
- URL: `jdbc:h2:mem:testdb`
- Username: `sa` 
- Password: (empty)

### Production (PostgreSQL)
```yaml
# src/main/resources/application.yml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/drimain
    username: postgres
    password: postgres
```

### Docker Setup (PostgreSQL)
```bash
# Quick PostgreSQL with Docker
docker run --name drimain-postgres \
  -e POSTGRES_DB=drimain \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 \
  -d postgres:15
```

---

## 📱 Mobile & Web Support

The Flutter frontend supports:
- **Web browsers** (primary deployment target)
- **iOS** mobile applications
- **Android** mobile applications
- **Desktop** (Linux, macOS, Windows) 

All platforms share the same codebase and connect to the unified REST API.

---

## ⚙️ System Health & Monitoring

### Health Check Endpoint

Monitor application health:
```bash
curl http://localhost:8080/actuator/health
```

Response:
```json
{
  "status": "UP",
  "components": {
    "db": {"status": "UP"},
    "diskSpace": {"status": "UP"}
  }
}
```

### Additional Endpoints
- `/actuator/info` - Application information
- `/swagger-ui/index.html` - Interactive API documentation
- `/swagger-ui` - Redirect to Swagger UI (convenience)

---

## 🌐 CORS Configuration

The backend allows requests from common development origins:
- `http://localhost:3000` (Flutter web dev)
- `http://localhost:5173` (Vite dev server) 
- `http://10.0.2.2:8080` (Android emulator)
- Various other localhost ports

**⚠️ TODO**: Restrict origins for production - only allow specific domains.

---

## 🔄 CI/CD Pipeline

GitHub Actions workflow (`.github/workflows/ci.yml`):

- ✅ **Backend Testing**: Maven test execution
- ✅ **Frontend Testing**: Flutter analyze and test
- ✅ **Integration Build**: Flutter web → Spring Boot static resources
- ✅ **Artifact Upload**: JAR file and build assets
- ✅ **Caching**: Maven and Flutter dependencies

---

## 📋 Next Steps & TODOs

### High Priority
- [ ] **Implement refresh token mechanism** - currently tokens expire after 1 hour
- [ ] **Add Flyway database migrations** - for better database version control
- [ ] **Add integration tests** - test API endpoints with test containers
- [ ] **Production JWT secret** - replace default secret in production

### Medium Priority  
- [ ] **User management UI** - admin interface for user management
- [ ] **Database connection pooling** - optimize database performance
- [ ] **API rate limiting** - prevent abuse
- [ ] **Request/response logging** - better debugging

### Development Improvements
- [ ] **Environment-specific configs** - separate dev/staging/prod settings
- [ ] **Docker multi-stage builds** - optimize Docker image size
- [ ] **CI/CD enhancements** - automated deployment pipelines
- [ ] **Monitoring & metrics** - production observability

### Security Enhancements
- [ ] **OAuth2 integration** - support external authentication providers  
- [ ] **Role-based permissions** - fine-grained access control
- [ ] **API versioning** - support multiple API versions
- [ ] **Input validation** - comprehensive request validation

---

## 🚧 Migration Status

This is an active migration from legacy Thymeleaf templates to a modern Flutter-based architecture:

- ✅ **REST API Infrastructure** - Complete
- ✅ **JWT Authentication** - Complete  
- ✅ **Flutter Foundation** - Complete
- ✅ **CI/CD Pipeline** - Complete
- 🔄 **Feature Migration** - In Progress
- ⏳ **Legacy UI Removal** - Planned

## 📚 Additional Resources

- **Spring Boot Documentation**: https://spring.io/projects/spring-boot
- **Flutter Documentation**: https://flutter.dev/docs
- **JWT.io**: https://jwt.io/
- **H2 Database Console**: http://localhost:8080/h2-console (when running)
- **OpenAPI/Swagger UI**: http://localhost:8080/swagger-ui/index.html" 
