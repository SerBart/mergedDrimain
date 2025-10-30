package drimer.drimain.service;

import drimer.drimain.model.Notification;
import drimer.drimain.model.User;
import drimer.drimain.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.security.core.Authentication;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class NotificationService {

    private final drimer.drimain.repository.NotificationRepository notificationRepository;
    private final UserRepository userRepository;

    // Modules we don't want to surface in notifications (case-insensitive)
    private static final String[] EXCLUDED_MODULES = new String[]{"czesci", "części", "czesc", "parts", "admin", "paneladmin"};

    /**
     * Zwraca listę powiadomień widocznych dla zalogowanego użytkownika.
     * - Powiadomienia przypisane bezpośrednio do użytkownika
     * - Powiadomienia globalne przypisane do modulów, do których użytkownik ma dostęp
     * Wyklucza powiadomienia dla modułów zdefiniowanych w EXCLUDED_MODULES.
     */
    public List<Notification> getForUser(Authentication authentication) {
        if (authentication == null || !authentication.isAuthenticated()) return List.of();
        String username = authentication.getName();
        User u = userRepository.findByUsername(username).orElse(null);
        if (u == null) return List.of();

        List<Notification> result = new ArrayList<>();
        // personal notifications
        result.addAll(notificationRepository.findByUserOrderByCreatedAtDesc(u));

        // module notifications (only for modules the user has)
        Set<String> modules = u.getModules();
        if (modules != null && !modules.isEmpty()) {
            List<Notification> moduleNotifs = modules.stream()
                    .filter(m -> m != null && !m.isBlank())
                    .filter(m -> !isExcludedModule(m))
                    .flatMap(m -> notificationRepository.findByUserIsNullAndModuleIgnoreCaseOrderByCreatedAtDesc(m).stream())
                    .collect(Collectors.toList());
            result.addAll(moduleNotifs);
        }

        // remove duplicates (by id) in case of overlap
        List<Notification> distinct = result.stream()
                .collect(Collectors.toMap(n -> n.getId(), n -> n, (a, b) -> a))
                .values().stream().collect(Collectors.toList());

        // sort by createdAt desc
        distinct.sort(Comparator.comparing(Notification::getCreatedAt).reversed());
        return distinct;
    }

    private boolean isExcludedModule(String module) {
        if (module == null) return false;
        String m = module.trim().toLowerCase();
        for (String ex : EXCLUDED_MODULES) {
            if (ex.equalsIgnoreCase(m)) return true;
        }
        return false;
    }

    /**
     * Tworzy powiadomienie modułowe (user=null) i zapisuje je.
     * Powiadomienia dla modułów z EXCLUDED_MODULES nie będą tworzone.
     */
    public Notification createModuleNotification(String module, drimer.drimain.model.NotificationType type, String title, String message, String link) {
        if (module != null && isExcludedModule(module)) return null;
        Notification n = new Notification();
        n.setModule(module);
        n.setType(type);
        n.setTitle(title);
        n.setMessage(message);
        n.setLink(link);
        n.setCreatedAt(Instant.now());
        n.setRead(false);
        return notificationRepository.save(n);
    }

    /**
     * Tworzy powiadomienie personalne dla wskazanego użytkownika.
     */
    public Notification createPersonalNotification(User user, drimer.drimain.model.NotificationType type, String title, String message, String link) {
        if (user == null) return null;
        Notification n = new Notification();
        n.setUser(user);
        n.setModule(null);
        n.setType(type);
        n.setTitle(title);
        n.setMessage(message);
        n.setLink(link);
        n.setCreatedAt(Instant.now());
        n.setRead(false);
        return notificationRepository.save(n);
    }
}
