# Drimain Web Mobile Application
Drimain is a Spring Boot web application for maintenance management with both web UI and REST API endpoints. It uses Java 17, H2 database for development, JWT authentication, and provides both Thymeleaf-based web interface and RESTful API for mobile clients.

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Working Effectively

### Prerequisites & Setup
- Java 17 is required and available on this system
- Use the Maven wrapper (`./mvnw`) - it's already executable 
- No additional SDK installation needed

### Build Process
- **Clean compile**: `./mvnw clean compile` -- takes ~5 seconds (30s on first run). NEVER CANCEL. Set timeout to 60+ seconds.
- **Full build with tests**: `./mvnw clean package` -- takes ~13 seconds total. NEVER CANCEL. Set timeout to 60+ seconds.
- **Run tests only**: `./mvnw test` -- takes ~12 seconds. NEVER CANCEL. Set timeout to 60+ seconds.
- **Skip tests during build**: `./mvnw package -DskipTests` -- takes ~6 seconds.

### Running the Application
- **Development mode**: `./mvnw spring-boot:run` -- starts in ~6 seconds, runs on port 8080
- **Production JAR**: `java -jar target/driMain-1.0.0.jar` -- runs on port 8080
- **Custom port**: Add `--server.port=XXXX` to either command
- **Reduce logging**: Add `--logging.level.org.hibernate.SQL=WARN --logging.level.root=INFO`

### Database Configuration
- **Development**: Uses H2 in-memory database (default profile)
- **H2 Console**: Available at http://localhost:8080/h2-console when running
  - URL: `jdbc:h2:mem:testdb`
  - Username: `sa`
  - Password: (empty)
- **PostgreSQL**: Use application-local.properties profile for production

### Default Test Accounts
- **Admin user**: username=`admin`, password=`admin123` (has ROLE_ADMIN, ROLE_USER)
- **Regular user**: username=`user`, password=`user123` (has ROLE_USER only)
- These are created automatically on first startup via DataInitializer

## Validation & Testing

### Manual Testing Scenarios
Always test these scenarios after making changes:
1. **Application startup**: Confirm app starts without errors in ~6 seconds
2. **Web UI access**: Navigate to http://localhost:8080/ - should redirect to login page
3. **Authentication**: Login with admin/admin123 and verify access to admin features
4. **API authentication**: Test `curl http://localhost:8080/api/parts` (should return 401)
5. **H2 Console**: Access database console for debugging

### API Documentation
- **OpenAPI JSON**: http://localhost:8080/v3/api-docs
- **Swagger UI**: http://localhost:8080/swagger-ui/index.html
- Main API endpoints:
  - `/api/auth/login` - Authentication
  - `/api/parts` - Parts management
  - `/api/raporty` - Reports management
  - `/api/zgloszenia` - Issues management

### Build & CI Validation Steps
- Always run `./mvnw clean compile` to verify compilation
- Always run `./mvnw test` to ensure tests pass
- Build times are measured: add 50% buffer for timeout values
- No additional linting or code quality tools are configured

## Common Tasks & Troubleshooting

### Development Workflow
1. Make code changes
2. Run `./mvnw clean compile` to verify compilation (~30s)
3. Run `./mvnw test` to verify tests pass (~20s)
4. Test functionality with `./mvnw spring-boot:run`
5. Use Swagger UI or test endpoints manually

### Key Project Structure
```
src/main/java/drimer/drimain/
├── DriMainApplication.java          # Main Spring Boot application
├── api/                             # REST API controllers and DTOs
├── config/                          # Configuration and data initialization
├── controller/                      # Web MVC controllers
├── model/                          # JPA entities
├── repository/                     # JPA repositories
├── security/                       # Security configuration and JWT handling
└── service/                        # Business logic services

src/main/resources/
├── application.properties          # H2 configuration (default)
├── application-local.properties    # PostgreSQL configuration
├── application.yml                 # Main configuration with JWT settings
├── db/migration/                   # Flyway database migrations
├── static/                         # Static web assets
└── templates/                      # Thymeleaf templates
```

### Important Configuration Files
- `pom.xml` - Maven dependencies and build configuration
- `application.properties` - H2 database config for development
- `application.yml` - Primary configuration with JWT and PostgreSQL settings
- `application-local.properties` - PostgreSQL production configuration

### Spring Boot Goals Available
- `./mvnw spring-boot:run` - Run application in development mode
- `./mvnw spring-boot:help` - Show available goals
- `./mvnw spring-boot:build-image` - Build OCI image using buildpacks

### Known Issues & Limitations
- Application may take extra time initializing data on first startup (role and user creation)
- Default JWT secret should be changed for production use
- H2 database data is lost on restart (in-memory)
- No code quality plugins (Checkstyle, SpotBugs, etc.) are configured

### Common Commands Reference
```bash
# Build and test
./mvnw clean compile                    # ~5s (30s first run) - NEVER CANCEL
./mvnw test                            # ~12s - NEVER CANCEL  
./mvnw clean package                   # ~13s - NEVER CANCEL
./mvnw package -DskipTests             # ~6s - Skip tests

# Run application  
./mvnw spring-boot:run                 # Development mode
java -jar target/driMain-1.0.0.jar     # Production JAR

# Test endpoints
curl http://localhost:8080/            # Should redirect to login (302)
curl http://localhost:8080/api/parts   # Should return 401 Unauthorized
```

### Environment Setup Summary
- Java 17: ✓ Available
- Maven wrapper: ✓ Available and executable
- Database: ✓ H2 configured and working
- Security: ✓ JWT authentication configured
- Documentation: ✓ Swagger UI available
- Default users: ✓ admin/admin123, user/user123

Always ensure the application builds and runs successfully before making changes, and verify your changes don't break existing functionality by running the manual testing scenarios.