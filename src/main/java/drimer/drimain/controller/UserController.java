package drimer.drimain.controller;

import drimer.drimain.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;
import jakarta.validation.Valid;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
@Slf4j
public class UserController {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    /**
     * NOTE: Endpoint for getting current user information with roles
     * Accessible by authenticated users only
     */
    @GetMapping("/me")
    @Transactional(readOnly = true)
    public ResponseEntity<?> getCurrentUser(@AuthenticationPrincipal UserDetails userDetails) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("Not authenticated");
            }

            Map<String, Object> userInfo = new HashMap<>();
            userRepository.findByUsernameFetchDzial(userDetails.getUsername())
                    .ifPresent(u -> userInfo.put("id", u.getId()));
            userInfo.put("username", userDetails.getUsername());
            userInfo.put("roles", userDetails.getAuthorities()
                    .stream().map(org.springframework.security.core.GrantedAuthority::getAuthority).toList());

            // Załaduj użytkownika wraz z działem, aby uniknąć LAZY poza transakcją
            userRepository.findByUsernameFetchDzial(userDetails.getUsername())
                    .ifPresent(u -> {
                        userInfo.put("email", u.getEmail());
                        if (u.getDzial() != null) {
                            userInfo.put("dzialId", u.getDzial().getId());
                            userInfo.put("dzialNazwa", u.getDzial().getNazwa());
                        }
                        userInfo.put("modules", u.getModules());
                    });

            log.debug("User info requested for: {}", userDetails.getUsername());
            return ResponseEntity.ok(userInfo);
        } catch (Exception e) {
            log.error("Error getting user info: {}", e.getMessage(), e);
            return ResponseEntity.status(500).body("Internal server error");
        }
    }

    @PostMapping("/me/password")
    @Transactional
    public ResponseEntity<?> changePassword(@AuthenticationPrincipal UserDetails userDetails,
                                            @Valid @RequestBody PasswordChangeRequest req) {
        if (userDetails == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("Not authenticated");
        }

        if (req.newPassword == null || !req.newPassword.equals(req.confirmNewPassword)) {
            return ResponseEntity.badRequest().body("Nowe hasła muszą być identyczne");
        }

        var user = userRepository.findByUsername(userDetails.getUsername())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));

        if (!passwordEncoder.matches(req.currentPassword, user.getPassword())) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body("Aktualne hasło jest nieprawidłowe");
        }

        user.setPassword(passwordEncoder.encode(req.newPassword));
        userRepository.save(user);
        return ResponseEntity.noContent().build();
    }

    public static class PasswordChangeRequest {
        @jakarta.validation.constraints.NotBlank(message = "Aktualne hasło jest wymagane")
        public String currentPassword;

        @jakarta.validation.constraints.NotBlank(message = "Nowe hasło jest wymagane")
        @jakarta.validation.constraints.Size(min = 8, max = 128, message = "Nowe hasło musi mieć od 8 do 128 znaków")
        public String newPassword;

        @jakarta.validation.constraints.NotBlank(message = "Potwierdzenie nowego hasła jest wymagane")
        public String confirmNewPassword;
    }
}