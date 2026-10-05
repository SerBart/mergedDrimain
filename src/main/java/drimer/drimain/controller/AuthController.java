package drimer.drimain.controller;

import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import drimer.drimain.api.dto.RefreshRequest;
import drimer.drimain.model.RefreshToken;
import drimer.drimain.model.Role;
import drimer.drimain.model.User;
import drimer.drimain.repository.RoleRepository;
import drimer.drimain.repository.UserRepository;
import drimer.drimain.security.JwtService;
import drimer.drimain.security.ModulesCatalog;
import drimer.drimain.service.BootstrapAdminService;
import drimer.drimain.service.CustomUserDetailsService;
import drimer.drimain.service.RefreshTokenService;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseCookie;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.Duration;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/auth")
@Slf4j
public class AuthController {

    private final AuthenticationManager authenticationManager;
    private final JwtService jwtService;
    private final CustomUserDetailsService userDetailsService;
    private final RefreshTokenService refreshTokenService;
    private final BootstrapAdminService bootstrapAdminService;
    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final PasswordEncoder passwordEncoder;
    private final ObjectMapper lenientJsonMapper = new ObjectMapper()
            .configure(JsonParser.Feature.ALLOW_SINGLE_QUOTES, true)
            .configure(JsonParser.Feature.ALLOW_UNQUOTED_FIELD_NAMES, true);

    public AuthController(AuthenticationManager authenticationManager,
                          JwtService jwtService,
                          CustomUserDetailsService userDetailsService,
                          RefreshTokenService refreshTokenService,
                          BootstrapAdminService bootstrapAdminService,
                          UserRepository userRepository,
                          RoleRepository roleRepository,
                          PasswordEncoder passwordEncoder) {
        this.authenticationManager = authenticationManager;
        this.jwtService = jwtService;
        this.userDetailsService = userDetailsService;
        this.refreshTokenService = refreshTokenService;
        this.bootstrapAdminService = bootstrapAdminService;
        this.userRepository = userRepository;
        this.roleRepository = roleRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @PostMapping(value = "/login", consumes = {MediaType.APPLICATION_JSON_VALUE, MediaType.APPLICATION_FORM_URLENCODED_VALUE, MediaType.TEXT_PLAIN_VALUE})
    public ResponseEntity<?> login(@RequestBody(required = false) String rawBody,
                                   @RequestParam(value = "username", required = false) String usernameParam,
                                   @RequestParam(value = "password", required = false) String passwordParam,
                                   @RequestParam(value = "rememberMe", required = false) Boolean rememberMeParam,
                                   HttpServletResponse response,
                                   HttpServletRequest httpRequest) {
        AuthRequest request = null;
        try {
            request = resolveAuthRequest(rawBody, usernameParam, passwordParam, rememberMeParam);
            if (request.getUsername() == null || request.getUsername().trim().isEmpty()
                    || request.getPassword() == null || request.getPassword().isEmpty()) {
                return ResponseEntity.badRequest().body("username and password are required");
            }

            String identifier = request.getUsername().trim();
            bootstrapAdminService.ensureBootstrapAdminForLogin(identifier, request.getPassword());

            String resolvedUsername = identifier;
            if (identifier.contains("@")) {
                String email = identifier.toLowerCase();
                var byEmail = userRepository.findByEmail(email);
                if (byEmail.isPresent()) {
                    resolvedUsername = byEmail.get().getUsername();
                }
            }

            authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(resolvedUsername, request.getPassword())
            );
            var userDetails = userDetailsService.loadUserByUsername(resolvedUsername);
            Map<String, Object> claims = new HashMap<>();
            claims.put("roles", userDetails.getAuthorities().stream()
                    .map(org.springframework.security.core.GrantedAuthority::getAuthority)
                    .toList());

            String accessToken = jwtService.generateAccessToken(userDetails.getUsername(), claims);

            var optUser = userRepository.findByUsername(userDetails.getUsername());
            if (optUser.isEmpty()) {
                log.warn("Authenticated principal '{}' not found in users table", userDetails.getUsername());
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("User not found");
            }
            User user = optUser.get();

            RefreshToken refreshToken = null;
            try {
                refreshToken = refreshTokenService.createRefreshToken(user);
            } catch (Exception e) {
                log.error("Failed to create refresh token for user {}: {}", user.getUsername(), e.getMessage(), e);
            }

            boolean isHttps = httpRequest.isSecure() || "https".equalsIgnoreCase(httpRequest.getHeader("X-Forwarded-Proto"));
            String sameSite = isHttps ? "None" : "Lax";

            ResponseCookie jwtCookie = ResponseCookie.from("JWT", accessToken)
                    .httpOnly(true)
                    .secure(isHttps)
                    .path("/")
                    .maxAge(Duration.ofHours(1))
                    .sameSite(sameSite)
                    .build();
            response.addHeader("Set-Cookie", jwtCookie.toString());

            if (refreshToken != null) {
                ResponseCookie.ResponseCookieBuilder refreshBuilder = ResponseCookie.from("REFRESH_TOKEN", refreshToken.getToken())
                        .httpOnly(true)
                        .secure(isHttps)
                        .path("/")
                        .sameSite(sameSite);

                if (request.isRememberMe()) {
                    Duration ttl = Duration.between(LocalDateTime.now(), refreshToken.getExpiry());
                    if (ttl.isNegative()) {
                        ttl = Duration.ofDays(7);
                    }
                    refreshBuilder.maxAge(ttl);
                }

                response.addHeader("Set-Cookie", refreshBuilder.build().toString());
            }

            log.info("User {} logged in successfully (rememberMe={})", userDetails.getUsername(), request.isRememberMe());
            return ResponseEntity.ok(new AuthResponse(accessToken, refreshToken == null ? null : refreshToken.getToken()));
        } catch (AuthenticationException e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("Bad credentials");
        } catch (Exception e) {
            log.error("Unexpected error during login for '{}': {}", request == null ? "<null>" : request.getUsername(), e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body("Internal server error");
        }
    }

    @PostMapping("/refresh")
    @Transactional
    public ResponseEntity<?> refresh(@RequestBody(required = false) RefreshRequest request,
                                     HttpServletRequest httpRequest,
                                     HttpServletResponse httpResponse) {
        try {
            String refreshTokenValue = request != null ? request.getRefreshToken() : null;
            if (refreshTokenValue == null || refreshTokenValue.trim().isEmpty()) {
                if (httpRequest.getCookies() != null) {
                    for (Cookie cookie : httpRequest.getCookies()) {
                        if ("REFRESH_TOKEN".equals(cookie.getName())) {
                            refreshTokenValue = cookie.getValue();
                            break;
                        }
                    }
                }
            }

            if (refreshTokenValue == null || refreshTokenValue.trim().isEmpty()) {
                return ResponseEntity.badRequest().body("Refresh token is required");
            }

            RefreshToken refreshToken = refreshTokenService.findByToken(refreshTokenValue)
                    .orElseThrow(() -> new RuntimeException("Invalid refresh token"));

            if (!refreshToken.isValid()) {
                refreshTokenService.revokeByToken(refreshTokenValue);
                clearAuthCookies(httpRequest, httpResponse);
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("Refresh token expired or revoked");
            }

            User user = refreshToken.getUser();
            var userDetails = userDetailsService.loadUserByUsername(user.getUsername());
            Map<String, Object> claims = new HashMap<>();
            claims.put("roles", userDetails.getAuthorities().stream()
                    .map(org.springframework.security.core.GrantedAuthority::getAuthority)
                    .toList());

            String newAccessToken = jwtService.generateAccessToken(user.getUsername(), claims);

            boolean isHttps = httpRequest.isSecure() || "https".equalsIgnoreCase(httpRequest.getHeader("X-Forwarded-Proto"));
            String sameSite = isHttps ? "None" : "Lax";
            ResponseCookie jwtCookie = ResponseCookie.from("JWT", newAccessToken)
                    .httpOnly(true)
                    .secure(isHttps)
                    .path("/")
                    .maxAge(Duration.ofHours(1))
                    .sameSite(sameSite)
                    .build();
            httpResponse.addHeader("Set-Cookie", jwtCookie.toString());

            log.info("Access token refreshed for user: {}", user.getUsername());
            return ResponseEntity.ok(new AuthResponse(newAccessToken, refreshTokenValue));
        } catch (Exception e) {
            log.warn("Failed to refresh token: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("Invalid refresh token");
        }
    }

    @PostMapping("/logout")
    public ResponseEntity<?> logout(HttpServletRequest request, HttpServletResponse response) {
        try {
            if (request.getCookies() != null) {
                for (Cookie cookie : request.getCookies()) {
                    if ("REFRESH_TOKEN".equals(cookie.getName()) && cookie.getValue() != null && !cookie.getValue().isBlank()) {
                        refreshTokenService.revokeByToken(cookie.getValue());
                    }
                }
            }
        } catch (Exception e) {
            log.warn("Failed to revoke refresh token during logout: {}", e.getMessage());
        }

        clearAuthCookies(request, response);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/me")
    @Transactional(readOnly = true)
    public ResponseEntity<?> me(@AuthenticationPrincipal UserDetails userDetails) {
        if (userDetails == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("Not authenticated");
        }

        return userRepository.findByUsernameFetchDzial(userDetails.getUsername())
                .<ResponseEntity<?>>map(user -> {
                    Map<String, Object> body = new HashMap<>();
                    body.put("id", user.getId());
                    body.put("username", user.getUsername());
                    body.put("email", user.getEmail());
                    body.put("roles", user.getAuthorities().stream()
                            .map(org.springframework.security.core.GrantedAuthority::getAuthority)
                            .toList());
                    body.put("modules", user.getModules());
                    if (user.getDzial() != null) {
                        body.put("dzialId", user.getDzial().getId());
                        body.put("dzialNazwa", user.getDzial().getNazwa());
                    }
                    return ResponseEntity.ok(body);
                })
                .orElseGet(() -> ResponseEntity.status(HttpStatus.NOT_FOUND).body("User not found"));
    }

    @PostMapping("/register")
    @Transactional
    public ResponseEntity<?> register(@RequestBody RegisterRequest request) {
        if (request == null || isBlank(request.getUsername()) || isBlank(request.getPassword()) || isBlank(request.getEmail())) {
            return ResponseEntity.badRequest().body("username, email and password are required");
        }

        if (userRepository.findByUsername(request.getUsername().trim()).isPresent()) {
            return ResponseEntity.status(HttpStatus.CONFLICT).body("Username already exists");
        }
        if (userRepository.findByEmail(request.getEmail().trim().toLowerCase()).isPresent()) {
            return ResponseEntity.status(HttpStatus.CONFLICT).body("Email already exists");
        }

        Role userRole = roleRepository.findByName("ROLE_USER")
                .orElseGet(() -> roleRepository.save(new Role("ROLE_USER")));

        User user = new User();
        user.setUsername(request.getUsername().trim());
        user.setEmail(request.getEmail().trim().toLowerCase());
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        user.setRoles(Set.of(userRole));
        user.setModules(request.getModules() == null ? Set.of() : ModulesCatalog.normalizeAndFilter(request.getModules()));
        userRepository.save(user);

        return ResponseEntity.status(HttpStatus.CREATED).body(Map.of("username", user.getUsername(), "email", user.getEmail()));
    }

    private void clearAuthCookies(HttpServletRequest request, HttpServletResponse response) {
        boolean isHttps = request.isSecure() || "https".equalsIgnoreCase(request.getHeader("X-Forwarded-Proto"));
        String sameSite = isHttps ? "None" : "Lax";

        ResponseCookie clearJwt = ResponseCookie.from("JWT", "")
                .httpOnly(true)
                .secure(isHttps)
                .path("/")
                .maxAge(Duration.ZERO)
                .sameSite(sameSite)
                .build();
        ResponseCookie clearRefresh = ResponseCookie.from("REFRESH_TOKEN", "")
                .httpOnly(true)
                .secure(isHttps)
                .path("/")
                .maxAge(Duration.ZERO)
                .sameSite(sameSite)
                .build();
        response.addHeader("Set-Cookie", clearJwt.toString());
        response.addHeader("Set-Cookie", clearRefresh.toString());
    }

    private AuthRequest resolveAuthRequest(String rawBody,
                                           String usernameParam,
                                           String passwordParam,
                                           Boolean rememberMeParam) {
        AuthRequest request = new AuthRequest();
        request.setUsername(usernameParam);
        request.setPassword(passwordParam);
        request.setRememberMe(Boolean.TRUE.equals(rememberMeParam));

        if (rawBody == null || rawBody.isBlank()) {
            return request;
        }

        try {
            JsonNode root = lenientJsonMapper.readTree(rawBody);
            if (root != null && root.isObject()) {
                if (root.hasNonNull("username")) {
                    request.setUsername(root.get("username").asText());
                }
                if (root.hasNonNull("password")) {
                    request.setPassword(root.get("password").asText());
                }
                if (root.has("rememberMe")) {
                    request.setRememberMe(root.get("rememberMe").asBoolean(false));
                }
                return request;
            }
        } catch (Exception ignored) {
            // Fallback below
        }

        if (rawBody.contains("=") && rawBody.contains("&")) {
            Map<String, String> pairs = new HashMap<>();
            for (String token : rawBody.split("&")) {
                int idx = token.indexOf('=');
                if (idx > 0) {
                    pairs.put(token.substring(0, idx), token.substring(idx + 1));
                }
            }
            request.setUsername(pairs.getOrDefault("username", request.getUsername()));
            request.setPassword(pairs.getOrDefault("password", request.getPassword()));
            request.setRememberMe(Boolean.parseBoolean(pairs.getOrDefault("rememberMe", String.valueOf(request.isRememberMe()))));
            return request;
        }

        return request;
    }

    private boolean isBlank(String value) {
        return value == null || value.trim().isEmpty();
    }

    @Data
    public static class AuthRequest {
        @NotBlank
        private String username;
        @NotBlank
        private String password;
        private boolean rememberMe;
    }

    @Data
    public static class AuthResponse {
        private final String token;
        private final String refreshToken;
        private final Instant expiresAt = Instant.now().plus(Duration.ofHours(1));
    }

    @Data
    public static class RegisterRequest {
        @NotBlank
        private String username;
        @NotBlank
        private String password;
        @NotBlank
        @Email
        private String email;
        private Set<String> modules = new LinkedHashSet<>();
    }
}
