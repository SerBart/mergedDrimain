package drimer.drimain.security;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;

public class JjwtVersionCheck {
    public static void main(String[] args) {
        var key = Keys.hmacShaKeyFor("ABCDEFGHIJKLMNOPQRSTUVWX1234567890!!".getBytes(StandardCharsets.UTF_8));
        // Jeśli to się kompiluje, verifyWith istnieje (0.12.x)
        var claims = Jwts.parser()
                .verifyWith(key)
                .build();
        System.out.println("verifyWith dostępne. Masz JJWT 0.12.x");
    }
}