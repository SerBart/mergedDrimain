package drimer.drimain.security;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.ProviderManager;
import org.springframework.security.authentication.dao.DaoAuthenticationProvider;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.userdetails.UserDetailsPasswordService;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.Arrays;
import java.util.List;

@Configuration
@RequiredArgsConstructor
@EnableMethodSecurity
public class SecurityConfig {

    private final JwtAuthFilter jwtAuthFilter;
    private final UserDetailsService userDetailsService;
    private final UserDetailsPasswordService userDetailsPasswordService;

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
                .cors(cors -> {})
                .csrf(AbstractHttpConfigurer::disable)
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(reg -> {
                    reg.requestMatchers(HttpMethod.OPTIONS, "/**").permitAll();

                    reg.requestMatchers("/api/auth/**").permitAll();
                    reg.requestMatchers("/actuator/**").permitAll();

                    reg.requestMatchers(HttpMethod.GET,
                            "/api/meta/maszyny",
                            "/api/meta/maszyny-simple",
                            "/api/maszyny",
                            "/api/maszyny/select"
                    ).permitAll();

                    if (h2ConsoleEnabled) {
                        reg.requestMatchers("/h2-console/**").permitAll();
                    }
                    if (swaggerEnabled) {
                        reg.requestMatchers("/v3/api-docs/**", "/swagger-ui/**", "/swagger-ui.html").permitAll();
                    }

                    reg.requestMatchers(HttpMethod.POST, "/api/raporty/**").authenticated();
                    reg.requestMatchers(HttpMethod.PUT, "/api/raporty/**").authenticated();
                    reg.requestMatchers(HttpMethod.PATCH, "/api/raporty/**").authenticated();
                    reg.requestMatchers(HttpMethod.DELETE, "/api/raporty/**").authenticated();

                    reg.requestMatchers(HttpMethod.POST, "/api/energia/readings").permitAll();
                    reg.requestMatchers("/api/**").authenticated();
                    reg.anyRequest().permitAll();
                })
                .exceptionHandling(e -> e
                        .authenticationEntryPoint(authenticationEntryPoint())
                        .accessDeniedHandler(accessDeniedHandler())
                )
                .headers(h -> {
                    h.referrerPolicy(ref -> ref.policy(org.springframework.security.web.header.writers.ReferrerPolicyHeaderWriter.ReferrerPolicy.NO_REFERRER));
                    h.contentTypeOptions(org.springframework.security.config.Customizer.withDefaults());
                    h.contentSecurityPolicy(csp -> csp.policyDirectives(contentSecurityPolicy));

                    if (hstsEnabled) {
                        h.httpStrictTransportSecurity(hsts -> hsts
                                .includeSubDomains(true)
                                .preload(true)
                                .maxAgeInSeconds(31536000)
                        );
                    }

                    h.frameOptions(frame -> frame.sameOrigin());
                });

        http.addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource(
            @Value("${app.cors.allowed-origins:*}") String allowedOriginsProp) {
        CorsConfiguration config = new CorsConfiguration();
        List<String> allowedOrigins = Arrays.stream(allowedOriginsProp.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .toList();

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
        DaoAuthenticationProvider provider = new DaoAuthenticationProvider();
        provider.setPasswordEncoder(passwordEncoder());
        provider.setUserDetailsService(userDetailsService);
        provider.setUserDetailsPasswordService(userDetailsPasswordService);
        return new ProviderManager(provider);
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new LegacyCompatiblePasswordEncoder();
    }
}
