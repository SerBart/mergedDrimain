package drimer.drimain.security;

import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.ProviderManager;
import org.springframework.security.authentication.dao.DaoAuthenticationProvider;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;

@Configuration
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthFilter jwtAuthFilter;
    private final UserDetailsService userDetailsService;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
                .csrf(AbstractHttpConfigurer::disable)
                .sessionManagement(session -> session
                        .sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(reg -> reg
                        // Authentication endpoints
                        .requestMatchers("/api/auth/**").permitAll()
                        
                        // Static assets (Flutter web + legacy)
                        .requestMatchers(
                                "/",
                                "/index.html",
                                "/css/**",
                                "/js/**", 
                                "/img/**",
                                "/assets/**",
                                "/icons/**",
                                "/manifest.json",
                                "/flutter.js",
                                "/main.dart.js",
                                "/favicon.ico",
                                "/canvaskit/**"
                        ).permitAll()
                        
                        // Swagger/OpenAPI
                        .requestMatchers(
                                "/v3/api-docs/**",
                                "/swagger-ui/**",
                                "/swagger-ui.html"
                        ).permitAll()
                        
                        // API endpoints (require authentication)
                        .requestMatchers("/api/**").authenticated()
                        
                        // Legacy web endpoints (deprecated but kept for transition)
                        .requestMatchers("/login").permitAll()
                        .requestMatchers("/dashboard").authenticated()
                        .requestMatchers("/admin/**").hasRole("ADMIN")
                        .requestMatchers("/zgloszenia/**").authenticated()
                        .requestMatchers("/raporty/**").authenticated()
                        
                        .anyRequest().authenticated()
                )
                .exceptionHandling(e -> e.authenticationEntryPoint(authenticationEntryPoint()));

        http.addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }

    @Bean
    public AuthenticationEntryPoint authenticationEntryPoint() {
        return (HttpServletRequest request,
                HttpServletResponse response,
                org.springframework.security.core.AuthenticationException authException) -> {

            String uri = request.getRequestURI();
            String accept = request.getHeader("Accept");

            boolean isApi = uri.startsWith("/api/");
            boolean wantsHtml = accept != null && accept.contains("text/html");

            if (isApi) {
                // API – return JSON 401
                response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                response.setContentType("application/json;charset=UTF-8");
                response.getWriter().write("{\"error\":\"Unauthorized\"}");
                return;
            }

            if (wantsHtml) {
                // HTML request – serve index.html for SPA routing (Flutter web)
                // This allows the Flutter app to handle authentication UI
                response.sendRedirect("/");
                return;
            }

            // Fallback for other requests
            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            response.setContentType("application/json;charset=UTF-8");
            response.getWriter().write("{\"error\":\"Unauthorized\"}");
        };
    }

    @Bean
    public AuthenticationManager authenticationManager() {
        DaoAuthenticationProvider p = new DaoAuthenticationProvider();
        p.setPasswordEncoder(passwordEncoder());
        p.setUserDetailsService(userDetailsService);
        return new ProviderManager(p);
    }

    @Bean
    public BCryptPasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}