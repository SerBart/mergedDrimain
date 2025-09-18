package drimer.drimain.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.*;

@Configuration
public class CorsConfig implements WebMvcConfigurer {

    @Override
    public void addCorsMappings(CorsRegistry reg) {
        // TODO: Restrict origins in production - only allow specific domains
        reg.addMapping("/api/**")
                .allowedOrigins(
                        "http://localhost:5173",     // Vite dev server
                        "http://localhost:4200",     // Angular dev server  
                        "http://localhost:3000",     // Flutter web dev server (common port)
                        "http://localhost:8080",     // Spring Boot (self)
                        "http://127.0.0.1:5173",     // Alternative localhost
                        "http://127.0.0.1:3000",     // Alternative localhost for Flutter
                        "http://10.0.2.2:8080",      // Android emulator
                        "http://10.0.2.2:5173",      // Android emulator dev server
                        "http://10.0.2.2:3000"       // Android emulator Flutter dev
                )
                .allowedMethods("GET","POST","PUT","PATCH","DELETE","OPTIONS")
                .allowCredentials(true);
    }
}