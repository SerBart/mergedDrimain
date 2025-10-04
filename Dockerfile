# Multi-stage Dockerfile for Spring Boot (Java 17)
# Build stage
FROM eclipse-temurin:17-jdk AS build
WORKDIR /workspace
COPY . .
# Normalize Windows line endings for mvnw and ensure it's executable, then build
RUN sed -i 's/\r$//' mvnw || true \
 && chmod +x mvnw || true \
 && ./mvnw -B -DskipTests package

# Runtime stage (slim JRE)
FROM eclipse-temurin:17-jre
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75.0"
WORKDIR /app
# copy built jar
COPY --from=build /workspace/target/driMain-1.0.0.jar /app/app.jar
# Railway/Heroku-like platforms inject PORT
ENV PORT=8080
EXPOSE 8080
# server.port is also bound from application.yml via ${PORT:8080}
ENTRYPOINT ["sh","-c","java $JAVA_TOOL_OPTIONS -jar /app/app.jar"]
