package drimer.drimain.security;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.junit.Test;

import java.nio.charset.StandardCharsets;

public class JjwtApiDetectionTest {

    @Test
    public void printApiVariant() throws Exception {
        var key = Keys.hmacShaKeyFor("ABCDEFGHIJKLMNOPQRSTUVWX1234567890!!".getBytes(StandardCharsets.UTF_8));
        boolean newApi;
        try {
            Jwts.parser().verifyWith(key).build();
            newApi = true;
        } catch (Throwable t) {
            newApi = false;
        }
        System.out.println("Nowe API JJWT 0.12.x dostępne? " + newApi);
        // Jeśli newApi=false a chcesz 0.12.x -> nadal stara wersja siedzi na classpath.
    }
}