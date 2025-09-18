package drimer.drimain.security;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.HashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class JwtServiceTest {

    private JwtService jwtService;

    @BeforeEach
    void setUp() {
        // Create JwtService with test configuration
        jwtService = new JwtService(
                60L, // 60 minutes TTL
                "", // empty base64Secret to trigger plain secret usage
                "test-secret-key-that-is-at-least-32-characters-long-for-hmac-sha256"
        );
    }

    @Test
    void shouldGenerateToken() {
        // Given
        String subject = "testuser";
        Map<String, Object> claims = new HashMap<>();
        claims.put("role", "USER");

        // When
        String token = jwtService.generate(subject, claims);

        // Then
        assertNotNull(token);
        assertFalse(token.isEmpty());
        assertTrue(token.contains("."));
    }

    @Test
    void shouldParseTokenAndExtractSubject() {
        // Given
        String subject = "testuser";
        Map<String, Object> claims = new HashMap<>();
        claims.put("role", "ADMIN");
        
        String token = jwtService.generate(subject, claims);

        // When
        String extractedSubject = jwtService.extractUsername(token);

        // Then
        assertEquals(subject, extractedSubject);
    }

    @Test
    void shouldParseTokenAndExtractClaims() {
        // Given
        String subject = "admin";
        Map<String, Object> claims = new HashMap<>();
        claims.put("role", "ADMIN");
        claims.put("department", "IT");
        
        String token = jwtService.generate(subject, claims);

        // When
        var parsedClaims = jwtService.parseSigned(token).getPayload();

        // Then
        assertEquals(subject, parsedClaims.getSubject());
        assertEquals("ADMIN", parsedClaims.get("role"));
        assertEquals("IT", parsedClaims.get("department"));
    }

    @Test
    void shouldValidateTokenSuccessfully() {
        // Given
        String subject = "validuser";
        Map<String, Object> claims = new HashMap<>();
        String token = jwtService.generate(subject, claims);

        // When
        boolean isValid = jwtService.isValid(token, subject);

        // Then
        assertTrue(isValid);
    }

    @Test
    void shouldRejectTokenWithWrongSubject() {
        // Given
        String subject = "validuser";
        String wrongSubject = "wronguser";
        Map<String, Object> claims = new HashMap<>();
        String token = jwtService.generate(subject, claims);

        // When
        boolean isValid = jwtService.isValid(token, wrongSubject);

        // Then
        assertFalse(isValid);
    }

    @Test
    void shouldThrowExceptionForInvalidToken() {
        // Given
        String invalidToken = "invalid.token.here";

        // When & Then
        assertThrows(Exception.class, () -> jwtService.extractUsername(invalidToken));
    }
}