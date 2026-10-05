package drimer.drimain.controller;

import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
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

import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.Map;
import java.util.Set;

@RestController
@RequestMapping("/api/auth")
@Slf4j
public class AuthController {

    private final AuthenticationManager authenticationManager;
    private final JwtService jwtService;
    private final CustomUserDetailsService userDetailsService;
    private final RefreshTokenService refreshTokenService;
    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final PasswordEncoder passwordEncoder;
    private final BootstrapAdminService bootstrapAdminService;

    private final ObjectMapper lenientJsonMapper = new ObjectMapper()
            .configure(JsonParser.Feature.ALLOW_SINGLE_QUOTES, true)
            .configure(JsonParser.Feature.ALLOW_UNQUOTED_FIELD_NAMES, true);

    public AuthController(AuthenticationManager authenticationManager,
                          JwtService jwtService,
                          CustomUserDetailsService userDetailsService,
                          RefreshTokenService refreshTokenService,
                          UserRepository userRepository,
                          RoleRepository roleRepository,
                          PasswordEncoder passwordEncoder,
                          BootstrapAdminService bootstrapAdminService) {
        this.authenticationManager = authenticationManager;
        this.jwtService = jwtService;
        this.userDetailsService = userDetailsService;
        this.refreshTokenService = refreshTokenService;
        this.userRepository = userRepository;
        this.roleRepository = roleRepository;
        this.passwordEncoder = passwordEncoder;
        this.bootstrapAdminService = bootstrapAdminService;
    }

    @PostMapping(value = "/login", consumes = {MediaType.APPLICATION_JSON_VALUE, MediaType.APPLICATION_FORM_URLENCODED_VALUE, MediaType.TEXT_PLAIN_VALUE})
    public ResponseEntity<?> login(@RequestBody(required = false) String rawBody,
                                   @RequestParam(value = "username", required = false) String usernameParam,
                                   @RequestParam(value = "password", required = false) String passwordParam,
                                   @RequestParam(value = "rememberMe", required = false) Boolean rememberMeParam,
                                   HttpServletResponse response,
                                   HttpServletRequest httpRequest) {
        try {
            AuthRequest request = resolveAuthRequest(rawBody, usernameParam, passwordParam, rememberMeParam);
            if (isBlank(request.getUsername()) || isBlank(request.getPassword())) {
                return ResponseEntity.badRequest().body("username and password are required");
            }

            String identifier = request.getUsername().trim();
            bootstrapAdminService.ensureBootstrapAdminForLogin(identifier, request.getPassword());

            String resolvedUsername = resolveUsername(identifier);
            authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(resolvedUsername, request.getPassword())
            );

            User user = userRepository.findByUsername(resolvedUsername)
                    .orElseThrow(() -> new IllegalStateException("Authenticated user not found in database"));
            UserDetails userDetails = userDetailsService.loadUserByUsername(user.getUsername());

            Map<String, Object> claims = new HashMap<>();
            claims.put("roles", userDetails.getAuthorities().stream()
                    .map(a -> a.getAuthority())
                    .toList());

            String accessToken = jwtService.generateAccessToken(userDetails.getUsername(), claims);
            RefreshToken refreshToken = refreshTokenService.createRefreshToken(user);

            boolean rememberMe = request.isRememberMe();
            writeAuthCookies(httpRequest, response, accessToken, refreshToken.getToken(), rememberMe);

            Map<String, Object> body = new HashMap<>();
            body.put("token", accessToken);
            body.put("accessToken", accessToken);
            body.put("refreshToken", refreshToken.getToken());
            body.put("roles", claims.get("roles"));

            return ResponseEntity.ok(body);
        } catch (AuthenticationException ex) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("Bad credentials");
        } catch (Exception ex) {
            log.error("Unexpected error during login for '{}': {}", usernameParam, ex.getMessage(), ex);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body("Login failed");
        }
    }

    @PostMapping(value = "/refresh", consumes = {MediaType.APPLICATION_JSON_VALUE, MediaType.APPLICATION_FORM_URLENCODED_VALUE, MediaType.TEXT_PLAIN_VALUE})
    public ResponseEntity<?> refresh(@RequestBody(required = false) String rawBody,
                                     @RequestParam(value = "refreshToken", required = false) String refreshTokenParam,
                                     HttpServletRequest request,
                                     HttpServletResponse response) {
        try {
            AuthRequest parsed = resolveAuthRequest(rawBody, null, null, null);
            String refreshTokenValue = !isBlank(refreshTokenParam) ? refreshTokenParam : parsed.getRefreshToken();

            if (isBlank(refreshTokenValue) && request.getCookies() != null) {
                for (Cookie cookie : request.getCookies()) {
                    if ("REFRESH_TOKEN".equals(cookie.getName()) && !isBlank(cookie.getValue())) {
                        refreshTokenValue = cookie.getValue();
                        break;
                    }
                }
            }

            if (isBlank(refreshTokenValue)) {
                return ResponseEntity.badRequest().body("Refresh token is required");
            }

            RefreshToken token = refreshTokenService.findByToken(refreshTokenValue)
                    .orElse(null);
            if (token == null || token.isRevoked()) {
                clearAuthCookies(request, response);
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("Invalid refresh token");
            }

            try {
                refreshTokenService.verifyExpiration(token);
            } catch (RuntimeException ex) {
                clearAuthCookies(request, response);
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("Refresh token expired or revoked");
            }

            User user = token.getUser();
            UserDetails userDetails = userDetailsService.loadUserByUsername(user.getUsername());
            Map<String, Object> claims = new HashMap<>();
            claims.put("roles", userDetails.getAuthorities().stream().map(a -> a.getAuthority()).toList());

            String accessToken = jwtService.generateAccessToken(user.getUsername(), claims);
            writeAccessCookie(request, response, accessToken, true);

            Map<String, Object> body = new HashMap<>();
            body.put("token", accessToken);
            body.put("accessToken", accessToken);
            body.put("roles", claims.get("roles"));
            return ResponseEntity.ok(body);
        } catch (Exception ex) {
            log.error("Unexpected error during refresh: {}", ex.getMessage(), ex);
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("Invalid refresh token");
        }
    }

    @PostMapping("/logout")
    public ResponseEntity<?> logout(HttpServletRequest request, HttpServletResponse response) {
        try {
            if (request.getCookies() != null) {
                for (Cookie cookie : request.getCookies()) {
                    if ("REFRESH_TOKEN".equals(cookie.getName()) && !isBlank(cookie.getValue())) {
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
                    body.put("roles", user.getAuthorities().stream().map(a -> a.getAuthority()).toList());
                    body.put("modules", user.getModules());
                    if (user.getDzial() != null) {
                        body.put("dzialId", user.getDzial().getId());
                        body.put("dzialNazwa", user.getDzial().getNazwa());
                    }
                    return ResponseEntity.ok(body);
                })
                .orElseGet(() -> ResponseEntity.status(HttpStatus.NOT_FOUND).body("User not found"));
    }

    @PostMapping(value = "/register", consumes = MediaType.APPLICATION_JSON_VALUE)
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
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(Map.of("username", user.getUsername(), "email", user.getEmail()));
    }

    private String resolveUsername(String identifier) {
        String normalized = identifier.trim();
        if (!normalized.contains("@")) {
            return normalized;
        }

        return userRepository.findByEmail(normalized.toLowerCase())
                .map(User::getUsername)
                .orElse(normalized);
    }

    private void writeAuthCookies(HttpServletRequest request,
                                  HttpServletResponse response,
                                  String accessToken,
                                  String refreshToken,
                                  boolean rememberMe) {
        boolean isHttps = isHttps(request);
        String sameSite = isHttps ? "None" : "Lax";

        Duration accessTtl = rememberMe ? Duration.ofDays(7) : Duration.ofHours(1);
        Duration refreshTtl = rememberMe ? Duration.ofDays(30) : Duration.ofDays(7);

        ResponseCookie jwtCookie = ResponseCookie.from("JWT", accessToken)
                .httpOnly(true)
                .secure(isHttps)
                .path("/")
                .sameSite(sameSite)
                .maxAge(accessTtl)
                .build();

        ResponseCookie refreshCookie = ResponseCookie.from("REFRESH_TOKEN", refreshToken)
                .httpOnly(true)
                .secure(isHttps)
                .path("/")
                .sameSite(sameSite)
                .maxAge(refreshTtl)
                .build();

        response.addHeader("Set-Cookie", jwtCookie.toString());
        response.addHeader("Set-Cookie", refreshCookie.toString());
    }

    private void writeAccessCookie(HttpServletRequest request,
                                   HttpServletResponse response,
                                   String accessToken,
                                   boolean preserveRememberMeWindow) {
        boolean isHttps = isHttps(request);
        String sameSite = isHttps ? "None" : "Lax";
        Duration accessTtl = preserveRememberMeWindow ? Duration.ofDays(7) : Duration.ofHours(1);

        ResponseCookie jwtCookie = ResponseCookie.from("JWT", accessToken)
                .httpOnly(true)
                .secure(isHttps)
                .path("/")
                .sameSite(sameSite)
                .maxAge(accessTtl)
                .build();

        response.addHeader("Set-Cookie", jwtCookie.toString());
    }

    private void clearAuthCookies(HttpServletRequest request, HttpServletResponse response) {
        boolean isHttps = isHttps(request);
        String sameSite = isHttps ? "None" : "Lax";

        ResponseCookie clearJwt = ResponseCookie.from("JWT", "")
                .httpOnly(true)
                .secure(isHttps)
                .path("/")
                .sameSite(sameSite)
                .maxAge(Duration.ZERO)
                .build();

        ResponseCookie clearRefresh = ResponseCookie.from("REFRESH_TOKEN", "")
                .httpOnly(true)
                .secure(isHttps)
                .path("/")
                .sameSite(sameSite)
                .maxAge(Duration.ZERO)
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
                if (root.hasNonNull("refreshToken")) {
                    request.setRefreshToken(root.get("refreshToken").asText());
                }
                if (root.hasNonNull("email")) {
                    request.setEmail(root.get("email").asText());
                }
                return request;
            }
        } catch (Exception ignored) {
            // Fallback to form parser below.
        }

        Map<String, String> pairs = parseFormEncoded(rawBody);
        if (!pairs.isEmpty()) {
            request.setUsername(pairs.getOrDefault("username", request.getUsername()));
            request.setPassword(pairs.getOrDefault("password", request.getPassword()));
            request.setRefreshToken(pairs.getOrDefault("refreshToken", request.getRefreshToken()));
            request.setEmail(pairs.getOrDefault("email", request.getEmail()));
            request.setRememberMe(Boolean.parseBoolean(
                    pairs.getOrDefault("rememberMe", String.valueOf(request.isRememberMe()))
            ));
        }

        return request;
    }

    private Map<String, String> parseFormEncoded(String rawBody) {
        Map<String, String> pairs = new HashMap<>();
        if (rawBody == null || rawBody.isBlank()) {
            return pairs;
        }

        for (String token : rawBody.split("&")) {
            int idx = token.indexOf('=');
            if (idx <= 0) {
                continue;
            }
            String key = URLDecoder.decode(token.substring(0, idx), StandardCharsets.UTF_8);
            String value = URLDecoder.decode(token.substring(idx + 1), StandardCharsets.UTF_8);
            pairs.put(key, value);
        }
        return pairs;
    }

    private boolean isHttps(HttpServletRequest request) {
        return request.isSecure() || "https".equalsIgnoreCase(request.getHeader("X-Forwarded-Proto"));
    }

    private boolean isBlank(String value) {
        return value == null || value.trim().isEmpty();
    }

    @Data
    private static class AuthRequest {
        private String username;
        private String password;
        private String refreshToken;
        private String email;
        private boolean rememberMe;
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
