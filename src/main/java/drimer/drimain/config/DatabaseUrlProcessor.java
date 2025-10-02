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
        // If datasource URL already set, honor it
        if (StringUtils.hasText(environment.getProperty("spring.datasource.url"))) {
            System.out.println("[DB-AUTO] Using existing spring.datasource.url: " + environment.getProperty("spring.datasource.url"));
            return;
        }

        Map<String, Object> props = new HashMap<>();

        String explicitUrl = environment.getProperty("SPRING_DATASOURCE_URL");
        if (!StringUtils.hasText(explicitUrl)) {
            explicitUrl = environment.getProperty("JDBC_DATABASE_URL");
        }

        if (StringUtils.hasText(explicitUrl)) {
            props.put("spring.datasource.url", explicitUrl);
            enablePostgresExtrasIfNeeded(environment, props, explicitUrl);
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
                enablePostgresExtrasIfNeeded(environment, props, jdbcUrl);
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
        if (StringUtils.hasText(pgHost) && StringUtils.hasText(pgDb)) {
            if (!StringUtils.hasText(pgPort)) pgPort = "5432";
            String jdbc = "jdbc:postgresql://" + pgHost + ":" + pgPort + "/" + pgDb + "?sslmode=require";
            props.put("spring.datasource.url", jdbc);
            if (StringUtils.hasText(pgUser) && !StringUtils.hasText(environment.getProperty("spring.datasource.username"))) {
                props.put("spring.datasource.username", pgUser);
            }
            if (StringUtils.hasText(pgPass) && !StringUtils.hasText(environment.getProperty("spring.datasource.password"))) {
                props.put("spring.datasource.password", pgPass);
            }
            enablePostgresExtrasIfNeeded(environment, props, jdbc);
            System.out.println("[DB-AUTO] Built JDBC from PG* vars -> spring.datasource.url: " + jdbc);
            applyProps(environment, props);
        } else {
            System.out.println("[DB-AUTO] No DB env detected. Will use fallback datasource (e.g., H2 if configured).");
        }
    }

    private void enablePostgresExtrasIfNeeded(ConfigurableEnvironment environment, Map<String, Object> props, String url) {
        if (url != null && url.startsWith("jdbc:postgresql:")) {
            // Enable Flyway unless explicitly disabled
            if (!StringUtils.hasText(environment.getProperty("spring.flyway.enabled"))) {
                props.put("spring.flyway.enabled", true);
                System.out.println("[DB-AUTO] Enabling Flyway for PostgreSQL datasource");
            }
            // Prefer validate in prod when postgres is used, unless overridden
            if (!StringUtils.hasText(environment.getProperty("spring.jpa.hibernate.ddl-auto"))) {
                props.put("spring.jpa.hibernate.ddl-auto", "validate");
                System.out.println("[DB-AUTO] Setting JPA ddl-auto=validate for PostgreSQL datasource");
            }
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
                String scheme = uri.getScheme();
                String host = uri.getHost();
                int port = (uri.getPort() > 0) ? uri.getPort() : 5432;
                String db = uri.getPath();
                if (db != null && db.startsWith("/")) db = db.substring(1);
                if (host == null || db == null) return null;
                String jdbc = "jdbc:postgresql://" + host + ":" + port + "/" + db + "?sslmode=require";
                // If username/password needed, they will be applied separately via parseUserPass
                return jdbc;
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
