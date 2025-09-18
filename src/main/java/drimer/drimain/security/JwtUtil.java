package drimer.drimain.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jws;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.io.Decoders;
import io.jsonwebtoken.security.Keys;

import javax.crypto.SecretKey;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Date;
import java.util.Map;

public class JwtUtil {

    private final SecretKey secretKey;
    private final long ttlMinutes;

    public JwtUtil(String base64Secret, long ttlMinutes) {
        // base64Secret musi być Base64; jeśli masz czysty tekst – użyj getBytes i NIE Decoders.BASE64
        this.secretKey = Keys.hmacShaKeyFor(Decoders.BASE64.decode(base64Secret));
        this.ttlMinutes = ttlMinutes;
    }

    public String generate(String username, Map<String, Object> extraClaims) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(username)
                .claims(extraClaims)
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(ttlMinutes, ChronoUnit.MINUTES)))
                .signWith(secretKey) // algorytm dobrany wg długości
                .compact();
    }

    public Jws<Claims> parseSigned(String jwt) {
        return Jwts.parser()
                .verifyWith(secretKey)   // TERAZ OK (SecretKey)
                .build()
                .parseSignedClaims(jwt);
    }

    public Claims getClaims(String jwt) {
        return parseSigned(jwt).getPayload();
    }

    public String getSubject(String jwt) {
        return getClaims(jwt).getSubject();
    }

    public boolean isValid(String jwt, String expectedUsername) {
        try {
            Claims c = getClaims(jwt);
            return expectedUsername.equals(c.getSubject()) &&
                    c.getExpiration() != null &&
                    c.getExpiration().after(new Date());
        } catch (Exception e) {
            return false;
        }
    }
}