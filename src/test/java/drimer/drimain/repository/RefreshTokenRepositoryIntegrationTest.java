package drimer.drimain.repository;

import drimer.drimain.DriMainApplication;
import drimer.drimain.model.RefreshToken;
import drimer.drimain.model.User;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.ImportAutoConfiguration;
import org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

import java.time.LocalDateTime;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;

@SpringBootTest(
        classes = DriMainApplication.class,
        properties = {
                "spring.flyway.enabled=false",
                "spring.autoconfigure.exclude=org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration"
        }
)
@ImportAutoConfiguration(exclude = FlywayAutoConfiguration.class)
@ActiveProfiles("test")
class RefreshTokenRepositoryIntegrationTest {

    @Autowired
    private RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private UserRepository userRepository;

    @Test
    void shouldLoadUserWithRefreshTokenOutsideTransaction() {
        String uniqueSuffix = UUID.randomUUID().toString().replace("-", "");
        String username = "refreshuser_" + uniqueSuffix;

        User user = new User();
        user.setUsername(username);
        user.setEmail(username + "@local");
        user.setPassword("secret");
        User savedUser = userRepository.save(user);

        RefreshToken refreshToken = new RefreshToken(
                savedUser,
                UUID.randomUUID().toString(),
                LocalDateTime.now().plusDays(1)
        );
        refreshTokenRepository.save(refreshToken);

        RefreshToken foundToken = refreshTokenRepository.findByToken(refreshToken.getToken())
                .orElseThrow(() -> new AssertionError("Refresh token should exist"));

        assertDoesNotThrow(() -> assertEquals(username, foundToken.getUser().getUsername()));
    }
}

