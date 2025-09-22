# --- Build stage ---
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -B -q -DskipTests dependency:go-offline
COPY src ./src
RUN mvn -B -q -DskipTests clean package

# --- Runtime stage ---
FROM eclipse-temurin:17-jre
WORKDIR /app
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75 -XX:+UseStringDeduplication -Dfile.encoding=UTF-8"
ENV SPRING_PROFILES_ACTIVE=prod
# Install curl for HEALTHCHECK
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=build /app/target/*.jar /app/app.jar
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 \
  CMD curl -fsS http://localhost:8080/actuator/health | grep -q '"status":"UP"' || exit 1
ENTRYPOINT [ "sh", "-c", "java $JAVA_OPTS -jar /app/app.jar" ]