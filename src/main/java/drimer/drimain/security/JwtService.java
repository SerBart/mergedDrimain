package drimer.drimain.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jws;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.io.Decoders;
import io.jsonwebtoken.security.Keys;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Date;
import java.util.Map;

@Service
public class JwtService {

    private static final Logger log = LoggerFactory.getLogger(JwtService.class);

    private final SecretKey secretKey;
    private final long ttlMinutes;

    public JwtService(
            @Value("${jwt.expiration.minutes:60}") long ttlMinutes,
            @Value("${jwt.secret.base64:}") String base64Secret,
            @Value("${jwt.secret.plain:}") String plainSecret
    ) {
        this.ttlMinutes = ttlMinutes;
        this.secretKey = buildKey(base64Secret, plainSecret);
        log.info("JwtService initialized. TTL={} minutes, keyAlgorithm={}, keyLengthBytes={}",
                ttlMinutes, secretKey.getAlgorithm(), secretKey.getEncoded().length);
    }

    private SecretKey buildKey(String base64Secret, String plainSecret) {
        try {
            byte[] keyBytes;
            if (!isBlank(base64Secret)) {
                log.debug("Initializing JWT key from Base64 property 'jwt.secret.base64'");
                keyBytes = Decoders.BASE64.decode(base64Secret.trim());
            } else if (!isBlank(plainSecret)) {
                log.debug("Initializing JWT key from plain property 'jwt.secret.plain'");
                keyBytes = plainSecret.getBytes(StandardCharsets.UTF_8);
            } else {
                throw new IllegalStateException(
                        "No JWT secret provided. Define either 'jwt.secret.base64' OR 'jwt.secret.plain'.");
            }

            if (keyBytes.length < 32) {
                throw new IllegalStateException(
                        "JWT secret too short: " + keyBytes.length +
                                " bytes. Need >=32 bytes for HS256. Provide longer secret.");
            }

            return Keys.hmacShaKeyFor(keyBytes);
        } catch (Exception ex) {
            log.error("Failed to initialize JWT SecretKey: {}", ex.getMessage(), ex);
            throw ex;
        }
    }

    private boolean isBlank(String s) {
        return s == null || s.trim().isEmpty();
    }

    public String generate(String subject, Map<String, Object> extras) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(subject)
                .claims(extras)
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(ttlMinutes, ChronoUnit.MINUTES)))
                .signWith(secretKey)
                .compact();
    }

    public Jws<Claims> parseSigned(String token) {
        return Jwts.parser()
                .verifyWith(secretKey)
                .build()
                .parseSignedClaims(token);
    }

    public String extractUsername(String token) {
        return parseSigned(token).getPayload().getSubject();
    }

    public boolean isValid(String token, String expected) {
        try {
            Claims c = parseSigned(token).getPayload();
            return expected.equals(c.getSubject()) &&
                    c.getExpiration() != null &&
                    c.getExpiration().after(new Date());
        } catch (Exception e) {
            log.debug("JWT invalid: {}", e.getMessage());
            return false;
        }
    }
}