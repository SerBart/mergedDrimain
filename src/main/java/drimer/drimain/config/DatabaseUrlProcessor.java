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
        // If datasource URL already set, honor it only if it's not the H2 fallback
        String existing = environment.getProperty("spring.datasource.url");
        if (StringUtils.hasText(existing) && !existing.startsWith("jdbc:h2:")) {
            System.out.println("[DB-AUTO] Using existing spring.datasource.url: " + existing);
            return;
        }

        Map<String, Object> props = new HashMap<>();

        String explicitUrl = environment.getProperty("SPRING_DATASOURCE_URL");
        if (!StringUtils.hasText(explicitUrl)) {
            explicitUrl = environment.getProperty("JDBC_DATABASE_URL");
        }

        if (StringUtils.hasText(explicitUrl)) {
            props.put("spring.datasource.url", explicitUrl);
            // Do not force Flyway/ddl-auto here; respect external config
            System.out.println("[DB-AUTO] Configured spring.datasource.url from explicit env: " + explicitUrl);
            applyProps(environment, props);
            return;
        }

        String databaseUrl = environment.getProperty("DATABASE_URL");
        if (StringUtils.hasText(databaseUrl)) {
            String jdbcUrl = toJdbcUrl(databaseUrl);
            if (jdbcUrl != null) {
                props.put("spring.datasource.url", jdbcUrl);
                // Try to extract username/password from URL if missing
                String[] creds = parseUserPass(databaseUrl);
                if (creds != null) {
                    if (!StringUtils.hasText(environment.getProperty("spring.datasource.username"))) {
                        props.put("spring.datasource.username", creds[0]);
                    }
                    if (!StringUtils.hasText(environment.getProperty("spring.datasource.password"))) {
                        props.put("spring.datasource.password", creds[1]);
                    }
                }
                System.out.println("[DB-AUTO] Derived JDBC from DATABASE_URL -> spring.datasource.url: " + jdbcUrl);
                applyProps(environment, props);
                return;
            } else {
                System.out.println("[DB-AUTO] DATABASE_URL present but could not parse to JDBC, will try PG* vars");
            }
        }

        // Railway often exposes PG* variables
        String pgHost = environment.getProperty("PGHOST");
        String pgPort = environment.getProperty("PGPORT");
        String pgDb   = environment.getProperty("PGDATABASE");
        String pgUser = environment.getProperty("PGUSER");
        String pgPass = environment.getProperty("PGPASSWORD");
        String pgSslMode = environment.getProperty("PGSSLMODE"); // optional
        if (StringUtils.hasText(pgHost) && StringUtils.hasText(pgDb)) {
            if (!StringUtils.hasText(pgPort)) pgPort = "5432";
            StringBuilder jdbc = new StringBuilder("jdbc:postgresql://").append(pgHost).append(":").append(pgPort).append("/").append(pgDb);
            // Only append sslmode if explicitly provided
            if (StringUtils.hasText(pgSslMode)) {
                jdbc.append("?sslmode=").append(pgSslMode);
            }
            props.put("spring.datasource.url", jdbc.toString());
            if (StringUtils.hasText(pgUser) && !StringUtils.hasText(environment.getProperty("spring.datasource.username"))) {
                props.put("spring.datasource.username", pgUser);
            }
            if (StringUtils.hasText(pgPass) && !StringUtils.hasText(environment.getProperty("spring.datasource.password"))) {
                props.put("spring.datasource.password", pgPass);
            }
            System.out.println("[DB-AUTO] Built JDBC from PG* vars -> spring.datasource.url: " + jdbc);
            applyProps(environment, props);
        } else {
            System.out.println("[DB-AUTO] No DB env detected. Will use fallback datasource (e.g., H2 if configured).");
        }
    }

    private void applyProps(ConfigurableEnvironment environment, Map<String, Object> props) {
        if (!props.isEmpty()) {
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
                if (host == null || db == null) return null;
                String query = uri.getQuery();
                StringBuilder jdbc = new StringBuilder("jdbc:postgresql://").append(host).append(":").append(port).append("/").append(db);
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
        return Ordered.LOWEST_PRECEDENCE;
    }
}
