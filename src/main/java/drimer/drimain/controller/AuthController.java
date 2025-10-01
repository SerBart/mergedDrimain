package drimer.drimain.controller;

import drimer.drimain.api.dto.RefreshRequest;
import drimer.drimain.model.RefreshToken;
import drimer.drimain.model.Role;
import drimer.drimain.model.User;
import drimer.drimain.repository.RoleRepository;
import drimer.drimain.repository.UserRepository;
import drimer.drimain.security.JwtService;
import drimer.drimain.service.CustomUserDetailsService;
import drimer.drimain.service.RefreshTokenService;
import lombok.Data;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;
import java.time.Duration;
import org.springframework.http.ResponseCookie;

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

    public AuthController(AuthenticationManager authenticationManager,
                          JwtService jwtService,
                          CustomUserDetailsService userDetailsService,
                          RefreshTokenService refreshTokenService,
                          UserRepository userRepository,
                          RoleRepository roleRepository,
                          PasswordEncoder passwordEncoder) {
        this.authenticationManager = authenticationManager;
        this.jwtService = jwtService;
        this.userDetailsService = userDetailsService;
        this.refreshTokenService = refreshTokenService;
        this.userRepository = userRepository;
        this.roleRepository = roleRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody AuthRequest request, HttpServletResponse response, HttpServletRequest httpRequest) {
        try {
            // Allow login via email as identifier as well
            String identifier = request.getUsername();
            String resolvedUsername = identifier;
            if (identifier != null && identifier.contains("@")) {
                String email = identifier.trim().toLowerCase();
                var byEmail = userRepository.findByEmail(email);
                if (byEmail.isPresent()) {
                    resolvedUsername = byEmail.get().getUsername();
                }
            }
            Authentication auth = authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(resolvedUsername, request.getPassword())
            );
            var userDetails = userDetailsService.loadUserByUsername(resolvedUsername);
            Map<String, Object> claims = new HashMap<>();
            claims.put("roles", userDetails.getAuthorities()
                    .stream().map(a -> a.getAuthority()).toList());

            // NOTE: Use new access token generation method
            String accessToken = jwtService.generateAccessToken(userDetails.getUsername(), claims);
            
            // NOTE: Create refresh token
            User user = userRepository.findByUsername(userDetails.getUsername())
                    .orElseThrow(() -> new RuntimeException("User not found"));
            RefreshToken refreshToken = refreshTokenService.createRefreshToken(user);

            // Detect if request is over HTTPS (behind proxy on Railway)
            boolean isHttps = httpRequest.isSecure() || "https".equalsIgnoreCase(httpRequest.getHeader("X-Forwarded-Proto"));

            // Set HttpOnly JWT cookie in a browser-friendly way (SameSite=None requires Secure)
            ResponseCookie jwtCookie = ResponseCookie.from("JWT", accessToken)
                    .httpOnly(true)
                    .secure(isHttps)
                    .path("/")
                    .maxAge(Duration.ofHours(1))
                    .sameSite("None")
                    .build();
            response.addHeader("Set-Cookie", jwtCookie.toString());

            log.info("User {} logged in successfully", userDetails.getUsername());
            return ResponseEntity.ok(new AuthResponse(accessToken, refreshToken.getToken()));
        } catch (AuthenticationException e) {
            return ResponseEntity.status(401).body("Bad credentials");
        }
    }

    // NOTE: Refresh token endpoint for JWT token refresh flow
    @PostMapping("/refresh")
    public ResponseEntity<?> refresh(@RequestBody RefreshRequest request) {
        try {
            String refreshTokenValue = request.getRefreshToken();
            if (refreshTokenValue == null || refreshTokenValue.trim().isEmpty()) {
                return ResponseEntity.status(400).body("Refresh token is required");
            }

            // Find and validate refresh token
            RefreshToken refreshToken = refreshTokenService.findByToken(refreshTokenValue)
                    .orElseThrow(() -> new RuntimeException("Invalid refresh token"));

            if (!refreshToken.isValid()) {
                refreshTokenService.revokeByToken(refreshTokenValue);
                return ResponseEntity.status(401).body("Refresh token expired or revoked");
            }

            // Generate new access token
            User user = refreshToken.getUser();
            var userDetails = userDetailsService.loadUserByUsername(user.getUsername());
            Map<String, Object> claims = new HashMap<>();
            claims.put("roles", userDetails.getAuthorities()
                    .stream().map(a -> a.getAuthority()).toList());

            String newAccessToken = jwtService.generateAccessToken(user.getUsername(), claims);

            log.info("Access token refreshed for user: {}", user.getUsername());
            return ResponseEntity.ok(new AuthResponse(newAccessToken, refreshTokenValue));
        } catch (Exception e) {
            log.warn("Failed to refresh token: {}", e.getMessage());
            return ResponseEntity.status(401).body("Invalid refresh token");
        }
    }

    // NOTE: User registration endpoint
    @PostMapping("/register")
    public ResponseEntity<?> register(@RequestBody RegisterRequest request) {
        try {
            // Validate input
            if (request.getEmail() == null || request.getEmail().trim().isEmpty()) {
                return ResponseEntity.badRequest().body("Email is required");
            }
            String email = request.getEmail().trim().toLowerCase();
            if (!isValidEmail(email)) {
                return ResponseEntity.badRequest().body("Invalid email format");
            }
            if (request.getPassword() == null || request.getPassword().trim().isEmpty()) {
                return ResponseEntity.badRequest().body("Password is required");
            }

            // Derive or validate username
            String username = request.getUsername();
            if (username == null || username.trim().isEmpty()) {
                username = deriveUsernameFromEmail(email);
            } else {
                username = username.trim();
            }

            // Check uniqueness
            if (userRepository.findByUsername(username).isPresent()) {
                // Try to make username unique by appending a number
                username = makeUsernameUnique(username);
            }
            if (userRepository.existsByEmail(email)) {
                return ResponseEntity.status(HttpStatus.CONFLICT).body("Email already registered");
            }

            // Create new user
            User user = new User();
            user.setUsername(username);
            user.setEmail(email);
            user.setPassword(passwordEncoder.encode(request.getPassword()));
            
            // Assign default ROLE_USER
            Role userRole = roleRepository.findByName("ROLE_USER")
                    .orElseThrow(() -> new RuntimeException("Default role ROLE_USER not found"));
            user.setRoles(Set.of(userRole));

            userRepository.save(user);

            // Generate tokens for immediate login
            var userDetails = userDetailsService.loadUserByUsername(user.getUsername());
            Map<String, Object> claims = new HashMap<>();
            claims.put("roles", userDetails.getAuthorities()
                    .stream().map(a -> a.getAuthority()).toList());

            String accessToken = jwtService.generateAccessToken(user.getUsername(), claims);
            RefreshToken refreshToken = refreshTokenService.createRefreshToken(user);

            log.info("User {} registered successfully (email: {})", user.getUsername(), user.getEmail());
            return ResponseEntity.status(HttpStatus.CREATED)
                    .body(new AuthResponse(accessToken, refreshToken.getToken()));

        } catch (Exception e) {
            log.error("Failed to register user: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body("Registration failed");
        }
    }

    private boolean isValidEmail(String email) {
        // Simple RFC 5322 compliant-ish regex (kept simple for server-side)
        Pattern p = Pattern.compile("^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+$");
        return p.matcher(email).matches();
    }

    private String deriveUsernameFromEmail(String email) {
        String base = email.split("@")[0];
        if (base.isBlank()) base = "user";
        return makeUsernameUnique(base);
    }

    private String makeUsernameUnique(String base) {
        String candidate = base;
        int suffix = 1;
        while (userRepository.findByUsername(candidate).isPresent()) {
            candidate = base + suffix;
            suffix++;
            if (suffix > 1000) {
                throw new IllegalStateException("Unable to generate unique username");
            }
        }
        return candidate;
    }

    @GetMapping("/me")
    public ResponseEntity<?> me(@RequestHeader(name = "Authorization", required = false) String authHeader,
                               HttpServletRequest request) {
        String token = null;

        // First try Authorization header
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            token = authHeader.substring(7);
        }

        // If no Authorization header, try JWT cookie
        if (token == null) {
            token = getJwtFromCookie(request);
        }

        if (token == null) {
            return ResponseEntity.status(401).body("No token");
        }

        try {
            String username = jwtService.extractUsername(token);
            var userDetails = userDetailsService.loadUserByUsername(username);
            
            // Create response with user session information
            Map<String, Object> userInfo = new HashMap<>();
            userInfo.put("username", username);
            userInfo.put("roles", userDetails.getAuthorities()
                    .stream().map(a -> a.getAuthority()).toList());
            // Add email if available
            userRepository.findByUsername(username).ifPresent(u -> userInfo.put("email", u.getEmail()));

            return ResponseEntity.ok(userInfo);
        } catch (Exception ex) {
            return ResponseEntity.status(401).body("Invalid token");
        }
    }

    private String getJwtFromCookie(HttpServletRequest request) {
        if (request.getCookies() != null) {
            for (Cookie cookie : request.getCookies()) {
                if ("JWT".equals(cookie.getName())) {
                    return cookie.getValue();
                }
            }
        }
        return null;
    }

    @Data
    public static class AuthRequest {
        private String username; // can be email as well
        private String password;
    }

    @Data
    public static class RegisterRequest {
        private String username; // optional; derived from email if missing
        private String email;    // required
        private String password; // required
    }

    @Data
    public static class AuthResponse {
        private final String accessToken;
        private final String refreshToken;
        private final String tokenType;
        private final long expiresIn; // in seconds
        
        public AuthResponse(String accessToken) {
            this.accessToken = accessToken;
            this.refreshToken = null;
            this.tokenType = "Bearer";
            this.expiresIn = 3600; // 1 hour default
        }
        
        public AuthResponse(String accessToken, String refreshToken) {
            this.accessToken = accessToken;
            this.refreshToken = refreshToken;
            this.tokenType = "Bearer";
            this.expiresIn = 3600; // 1 hour
        }
        
        public AuthResponse(String accessToken, String refreshToken, long expiresIn) {
            this.accessToken = accessToken;
            this.refreshToken = refreshToken;
            this.tokenType = "Bearer";
            this.expiresIn = expiresIn;
        }

        // Backward compatibility for the tests that expect "token" field
        public String getToken() {
            return accessToken;
        }
    }
}
