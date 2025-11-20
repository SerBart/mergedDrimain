package drimer.drimain.security;

import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.ProviderManager;
import org.springframework.security.authentication.dao.DaoAuthenticationProvider;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.http.HttpMethod;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.util.Arrays;
import java.util.List;

@Configuration
@RequiredArgsConstructor
@EnableMethodSecurity(prePostEnabled = true)
public class SecurityConfig {

    private final JwtAuthFilter jwtAuthFilter;
    private final UserDetailsService userDetailsService;

    @Value("${app.security.h2-console-enabled:true}")
    private boolean h2ConsoleEnabled;

    @Value("${app.security.swagger-enabled:true}")
    private boolean swaggerEnabled;

    @Value("${app.security.hsts-enabled:false}")
    private boolean hstsEnabled;

    @Value("${app.security.csp:default-src 'self' https: data: blob: 'unsafe-inline' 'unsafe-eval';}")
    private String contentSecurityPolicy;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
                // Enable CORS first so it can handle preflight
                .cors(cors -> {})
                .csrf(AbstractHttpConfigurer::disable)
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(reg -> {
                    // Allow CORS preflight calls
                    reg.requestMatchers(HttpMethod.OPTIONS, "/**").permitAll();

                    reg.requestMatchers("/api/auth/**").permitAll();
                    reg.requestMatchers("/actuator/**").permitAll();
                    reg.requestMatchers(
                            "/", "/index.html",
                            "/css/**", "/js/**", "/img/**",
                            "/assets/**", "/icons/**", "/canvaskit/**",
                            "/manifest.json",
                            "/flutter.js", "/main.dart.js",
                            "/flutter_bootstrap.js", "/flutter_service_worker.js",
                            "/version.json",
                            "/favicon.ico", "/favicon.png"
                    ).permitAll();
                    if (h2ConsoleEnabled) { reg.requestMatchers("/h2-console/**").permitAll(); }
                    if (swaggerEnabled) { reg.requestMatchers("/v3/api-docs/**", "/swagger-ui/**", "/swagger-ui.html").permitAll(); }

                    // Public GET endpoints for machine lists used by forms
                    reg.requestMatchers(HttpMethod.GET,
                            "/api/meta/maszyny",
                            "/api/meta/maszyny-simple",
                            "/api/maszyny",
                            "/api/maszyny/select"
                    ).permitAll();

                    // Raporty: tworzenie / edycja dla każdego zalogowanego użytkownika (rola USER/BIURO/ADMIN), kasowanie tylko ADMIN
                    reg.requestMatchers(HttpMethod.POST, "/api/raporty/**").authenticated();
                    reg.requestMatchers(HttpMethod.PUT, "/api/raporty/**").authenticated();
                    reg.requestMatchers(HttpMethod.PATCH, "/api/raporty/**").authenticated();
                    reg.requestMatchers(HttpMethod.DELETE, "/api/raporty/**").hasRole("ADMIN");

                    // Pozostałe API wymagają uwierzytelnienia
                    reg.requestMatchers("/api/**").authenticated();
                    reg.anyRequest().authenticated();
                })
                .exceptionHandling(e -> e
                        .authenticationEntryPoint(authenticationEntryPoint())
                        .accessDeniedHandler(accessDeniedHandler())
                )
                .headers(h -> {
                    // Referrer-Policy, X-Content-Type-Options
                    h.referrerPolicy(ref -> ref.policy(org.springframework.security.web.header.writers.ReferrerPolicyHeaderWriter.ReferrerPolicy.NO_REFERRER));
                    h.contentTypeOptions(org.springframework.security.config.Customizer.withDefaults());

                    // Content-Security-Policy — uwaga: Flutter Web może wymagać 'unsafe-inline'/'unsafe-eval'
                    h.contentSecurityPolicy(csp -> csp.policyDirectives(contentSecurityPolicy));

                    // HSTS — włącz tylko, gdy skonfigurowane (np. w prod za SSL/proxy)
                    if (hstsEnabled) {
                        h.httpStrictTransportSecurity(hsts -> hsts
                                .includeSubDomains(true)
                                .preload(true)
                                .maxAgeInSeconds(31536000)
                        );
                    }

                    // Frame options — sameOrigin pozwala na H2 w tej samej domenie
                    h.frameOptions(f -> f.sameOrigin());
                });

        http.addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }

    // Global CORS configuration backed by property app.cors.allowed-origins
    @Bean
    public CorsConfigurationSource corsConfigurationSource(
            @Value("${app.cors.allowed-origins:*}") String allowedOriginsProp) {
        CorsConfiguration config = new CorsConfiguration();
        List<String> allowedOrigins = Arrays.stream(allowedOriginsProp.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .toList();

        // Zawsze używaj patterns, aby poprawnie echo-ować origin przy credentials
        config.setAllowedOriginPatterns(allowedOrigins);

        config.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));
        config.setExposedHeaders(Arrays.asList("Set-Cookie", "Authorization", "Content-Type"));
        config.setAllowCredentials(true);
        config.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
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
                response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                response.setContentType("application/json;charset=UTF-8");
                response.getWriter().write("{\"error\":\"Unauthorized\"}");
                return;
            }

            if (wantsHtml) {
                // HTML request – przekieruj do strony głównej SPA
                response.sendRedirect("/");
                return;
            }

            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            response.setContentType("application/json;charset=UTF-8");
            response.getWriter().write("{\"error\":\"Unauthorized\"}");
        };
    }

    @Bean
    public AccessDeniedHandler accessDeniedHandler() {
        return (HttpServletRequest request,
                HttpServletResponse response,
                org.springframework.security.access.AccessDeniedException accessDeniedException) -> {

            String uri = request.getRequestURI();
            boolean isApi = uri.startsWith("/api/");

            if (isApi) {
                response.setStatus(HttpServletResponse.SC_FORBIDDEN);
                response.setContentType("application/json;charset=UTF-8");
                response.getWriter().write("{\"error\":\"Access denied\"}");
                return;
            }

            response.sendRedirect("/");
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
