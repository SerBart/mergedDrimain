package drimer.drimain.config;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.env.EnvironmentPostProcessor;
import org.springframework.core.Ordered;
import org.springframework.core.env.ConfigurableEnvironment;
import org.springframework.core.env.MapPropertySource;
import org.springframework.util.StringUtils;

import java.net.URI;
import java.util.HashMap;
import java.util.Map;

public class DatabaseUrlProcessor implements EnvironmentPostProcessor, Ordered {

    @Override
    public void postProcessEnvironment(ConfigurableEnvironment environment, SpringApplication application) {
        Map<String, Object> props = new HashMap<>();

        // Priorytet 1: Jawny SPRING_DATASOURCE_URL lub JDBC_DATABASE_URL ustawiony przez użytkownika
        String explicitUrl = environment.getProperty("SPRING_DATASOURCE_URL");
        if (!StringUtils.hasText(explicitUrl)) {
            explicitUrl = environment.getProperty("JDBC_DATABASE_URL");
        }
        if (StringUtils.hasText(explicitUrl) && explicitUrl.startsWith("jdbc:")) {
            props.put("spring.datasource.url", explicitUrl);
            System.out.println("[DB-AUTO] Using explicit JDBC URL from env: " + explicitUrl);
            applyProps(environment, props);
            return;
        }

        // Priorytet 2: DATABASE_URL w formacie Railway (postgresql:// lub postgres://)
        String databaseUrl = environment.getProperty("DATABASE_URL");
        if (StringUtils.hasText(databaseUrl)) {
            String jdbcUrl = toJdbcUrl(databaseUrl);
            if (jdbcUrl != null) {
                props.put("spring.datasource.url", jdbcUrl);
                String[] creds = parseUserPass(databaseUrl);
                if (creds != null) {
                    props.put("spring.datasource.username", creds[0]);
                    props.put("spring.datasource.password", creds[1]);
                }
                System.out.println("[DB-AUTO] Converted DATABASE_URL -> JDBC: " + jdbcUrl);
                applyProps(environment, props);
                return;
            } else if (databaseUrl.startsWith("jdbc:")) {
                // DATABASE_URL już ma prefiks jdbc:
                props.put("spring.datasource.url", databaseUrl);
                System.out.println("[DB-AUTO] DATABASE_URL already in JDBC format: " + databaseUrl);
                applyProps(environment, props);
                return;
            } else {
                System.out.println("[DB-AUTO] DATABASE_URL present but could not parse: " + databaseUrl);
            }
        }

        // Priorytet 3: Zmienne PG* z Railway (PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD)
        String pgHost = environment.getProperty("PGHOST");
        String pgPort = environment.getProperty("PGPORT");
        String pgDb   = environment.getProperty("PGDATABASE");
        String pgUser = environment.getProperty("PGUSER");
        String pgPass = environment.getProperty("PGPASSWORD");
        String pgSslMode = environment.getProperty("PGSSLMODE");

        if (StringUtils.hasText(pgHost) && StringUtils.hasText(pgDb)) {
            if (!StringUtils.hasText(pgPort)) pgPort = "5432";
            StringBuilder jdbc = new StringBuilder("jdbc:postgresql://")
                    .append(pgHost).append(":").append(pgPort).append("/").append(pgDb);
            if (StringUtils.hasText(pgSslMode)) {
                jdbc.append("?sslmode=").append(pgSslMode);
            } else {
                jdbc.append("?sslmode=disable");
            }
            props.put("spring.datasource.url", jdbc.toString());
            if (StringUtils.hasText(pgUser)) props.put("spring.datasource.username", pgUser);
            if (StringUtils.hasText(pgPass)) props.put("spring.datasource.password", pgPass);
            System.out.println("[DB-AUTO] Built JDBC from PG* vars -> " + jdbc);
            applyProps(environment, props);
            return;
        }

        // Priorytet 4: Użyj już skonfigurowanego URL jeśli nie jest to H2 ani localhost fallback
        String existing = environment.getProperty("spring.datasource.url");
        if (StringUtils.hasText(existing) && !existing.startsWith("jdbc:h2:") && !existing.contains("localhost")) {
            System.out.println("[DB-AUTO] Using pre-configured spring.datasource.url: " + existing);
            return;
        }

        System.out.println("[DB-AUTO] No Railway DB env vars found. Using H2 fallback.");
    }

    private void applyProps(ConfigurableEnvironment environment, Map<String, Object> props) {
        if (!props.isEmpty()) {
            // addFirst = najwyższy priorytet, nadpisuje wszystko (application.yml, application-prod.yml)
            environment.getPropertySources().addFirst(new MapPropertySource("runtime-db-autoconfig", props));
        }
    }

    private String[] parseUserPass(String url) {
        try {
            URI uri = URI.create(url.replace("postgres://", "http://").replace("postgresql://", "http://"));
            String userInfo = uri.getUserInfo();
            if (userInfo != null && userInfo.contains(":")) {
                String[] parts = userInfo.split(":", 2);
                return new String[]{parts[0], parts[1]};
            }
        } catch (Exception ignored) {}
        return null;
    }

    private String toJdbcUrl(String url) {
        try {
            if (url.startsWith("postgres://") || url.startsWith("postgresql://")) {
                URI uri = URI.create(url);
                String host = uri.getHost();
                int port = (uri.getPort() > 0) ? uri.getPort() : 5432;
                String db = uri.getPath();
                if (db != null && db.startsWith("/")) db = db.substring(1);
                if (host == null || db == null || db.isEmpty()) return null;
                String query = uri.getQuery();
                StringBuilder jdbc = new StringBuilder("jdbc:postgresql://")
                        .append(host).append(":").append(port).append("/").append(db);
                if (StringUtils.hasText(query)) {
                    jdbc.append("?").append(query);
                }
                return jdbc.toString();
            }
            if (url.startsWith("jdbc:postgresql:")) {
                return url;
            }
        } catch (Exception ignored) {}
        return null;
    }

    @Override
    public int getOrder() {
        // Uruchamiamy PO ConfigDataEnvironmentPostProcessor (LOWEST_PRECEDENCE - 10)
        // żeby widzieć już załadowane właściwości, ale nadpisujemy je przez addFirst
        return Ordered.LOWEST_PRECEDENCE - 5;
    }
}
