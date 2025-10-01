package drimer.drimain.controller;

import drimer.drimain.service.CustomUserDetailsService;
import drimer.drimain.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
@Slf4j
public class UserController {

    private final CustomUserDetailsService userDetailsService;
    private final UserRepository userRepository;

    /**
     * NOTE: Endpoint for getting current user information with roles
     * Accessible by authenticated users only
     */
    @GetMapping("/me")
    public ResponseEntity<?> getCurrentUser(@AuthenticationPrincipal UserDetails userDetails) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("Not authenticated");
            }

            Map<String, Object> userInfo = new HashMap<>();
            userInfo.put("username", userDetails.getUsername());
            userInfo.put("roles", userDetails.getAuthorities()
                    .stream().map(a -> a.getAuthority()).toList());
            userRepository.findByUsername(userDetails.getUsername())
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
            log.error("Error getting user info: {}", e.getMessage());
            return ResponseEntity.status(500).body("Internal server error");
        }
    }
}