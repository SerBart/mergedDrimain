package drimer.drimain.controller;

import drimer.drimain.api.dto.NotificationDTO;
import drimer.drimain.api.mapper.NotificationMapper;
import drimer.drimain.service.NotificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.stream.Collectors;

// New imports
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.http.ResponseEntity;
import org.springframework.http.HttpStatus;
import drimer.drimain.repository.UserRepository;
import drimer.drimain.model.User;
import drimer.drimain.model.NotificationType;
import drimer.drimain.model.Notification;
import drimer.drimain.repository.NotificationRepository;

@RestController
@RequestMapping("/api/notifications")
@RequiredArgsConstructor
public class NotificationRestController {

    private final NotificationService notificationService;
    private final UserRepository userRepository;
    private final NotificationRepository notificationRepository;

    @GetMapping
    @PreAuthorize("isAuthenticated()")
    public List<NotificationDTO> list(Authentication authentication) {
        return notificationService.getForUser(authentication).stream()
                .map(NotificationMapper::toDto)
                .collect(Collectors.toList());
    }

    @GetMapping("/raw")
    @PreAuthorize("isAuthenticated()")
    public List<NotificationDTO> rawAll() {
        return notificationRepository.findAll().stream()
                .map(NotificationMapper::toDto)
                .collect(Collectors.toList());
    }

    /**
     * Test endpoint to create a notification quickly for debugging.
     * - ?personal=true -> creates personal notification for current user
     * - default -> creates module notification for 'Zgloszenia'
     */
    @PostMapping("/test")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<NotificationDTO> createTest(@RequestParam(defaultValue = "false") boolean personal,
                                                      Authentication authentication) {
        if (authentication == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        Notification n = null;
        if (personal) {
            User u = userRepository.findByUsername(authentication.getName()).orElse(null);
            if (u == null) return ResponseEntity.status(HttpStatus.BAD_REQUEST).build();
            n = notificationService.createPersonalNotification(u, NotificationType.GENERIC, "Test: powiadomienie osobiste", "To jest testowe powiadomienie personalne", null);
        } else {
            n = notificationService.createModuleNotification("Zgloszenia", NotificationType.GENERIC, "Test: powiadomienie modułowe", "To jest testowe powiadomienie modułowe", null);
        }
        if (n == null) return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        return ResponseEntity.status(HttpStatus.CREATED).body(NotificationMapper.toDto(n));
    }
}
