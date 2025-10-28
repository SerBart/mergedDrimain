package drimer.drimain.security;

import drimer.drimain.model.User;
import drimer.drimain.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

@Component("moduleGuard")
@RequiredArgsConstructor
public class ModuleGuard {

    private final UserRepository userRepository;

    /**
     * Sprawdza czy zalogowany użytkownik ma dostęp do wskazanego modułu (kafelka).
     * Nazwy porównywane case-insensitive.
     */
    public boolean has(String moduleName) {
        if (moduleName == null || moduleName.isBlank()) return false;
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated()) return false;
        String username = auth.getName();
        return userRepository.findByUsername(username)
                .map(User::getModules)
                .map(set -> set.stream().anyMatch(m -> m != null && m.equalsIgnoreCase(moduleName)))
                .orElse(false);
    }
}

