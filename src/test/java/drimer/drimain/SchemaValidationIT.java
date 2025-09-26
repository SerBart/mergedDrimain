package drimer.drimain;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;
import org.testcontainers.containers.PostgreSQLContainer;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.NONE)
@Testcontainers
class SchemaValidationIT {

    @Container
    static final PostgreSQLContainer<?> POSTGRES =
            new PostgreSQLContainer<>(DockerImageName.parse("postgres:16-alpine"))
                    .withDatabaseName("drimain")
                    .withUsername("test")
                    .withPassword("test");

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry r) {
        r.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        r.add("spring.datasource.username", POSTGRES::getUsername);
        r.add("spring.datasource.password", POSTGRES::getPassword);
        r.add("spring.datasource.driver-class-name", () -> "org.postgresql.Driver");

        // Ważne: walidacja względem encji + migracje Flyway przy starcie
        r.add("spring.jpa.hibernate.ddl-auto", () -> "validate");
        r.add("spring.flyway.enabled", () -> "true");
        r.add("spring.flyway.clean-disabled", () -> "true");
        r.add("spring.flyway.validate-on-migrate", () -> "true");
    }

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    void contextLoads_andSchemaIsValid() {
        // Jeśli kontekst wystartował, Flyway wykonał migracje, a Hibernate validate nie zgłosił błędów – test przechodzi.
    }

    @Test
    void frequencyColumnExists() {
        Integer cnt = jdbcTemplate.queryForObject(
                "SELECT count(*) FROM information_schema.columns WHERE table_name='harmonogramy' AND column_name='frequency'",
                Integer.class
        );
        assertThat(cnt).isNotNull();
        assertThat(cnt).isEqualTo(1);
    }

    @Test
    void dzialIdColumnExists() {
        Integer cnt = jdbcTemplate.queryForObject(
                "SELECT count(*) FROM information_schema.columns WHERE table_name='harmonogramy' AND column_name='dzial_id'",
                Integer.class
        );
        assertThat(cnt).isNotNull();
        assertThat(cnt).isEqualTo(1);
    }
}