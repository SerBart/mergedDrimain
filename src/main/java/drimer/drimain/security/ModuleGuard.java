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
     * Dodatkowo: użytkownicy z rolą ROLE_ADMIN mają dostęp do wszystkich modułów.
     */
    public boolean has(String moduleName) {
        if (moduleName == null || moduleName.isBlank()) return false;
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated()) return false;
        String username = auth.getName();

        // Pobierz użytkownika i sprawdź najpierw rolę ADMIN — jeżeli ma, zwróć true.
        return userRepository.findByUsername(username)
                .map(u -> {
                    // Jeżeli użytkownik ma rolę admin, od razu przyznaj dostęp
                    boolean isAdmin = u.getRoles().stream()
                            .anyMatch(r -> "ROLE_ADMIN".equalsIgnoreCase(r.getName()));
                    if (isAdmin) return true;

                    // W przeciwnym wypadku sprawdź uprawnienia do modułu
                    return u.getModules().stream()
                            .anyMatch(m -> m != null && m.equalsIgnoreCase(moduleName));
                })
                .orElse(false);
    }
}
