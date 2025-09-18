//package drimer.drimain.controller; // Zmień na Twój package
//
//import drimer.drimain.model.Osoba;
//import drimer.drimain.repository.OsobaRepository;
//import jakarta.servlet.http.HttpSession;
//import org.springframework.beans.factory.annotation.Autowired;
//import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
//import org.springframework.stereotype.Controller;
//import org.springframework.ui.Model;
//import org.springframework.web.bind.annotation.GetMapping;
//import org.springframework.web.bind.annotation.PostMapping;
//import org.springframework.web.bind.annotation.RequestParam;
//
//import java.util.Optional;
//
//@Controller
//public class LoginController {
//
//    @Autowired
//    private OsobaRepository osobaRepository;
//
//    @Autowired
//    private BCryptPasswordEncoder passwordEncoder;
//
//    @GetMapping("/login")
//    public String showLoginForm() {
//        System.out.println("Wyświetlanie formularza logowania"); // Debug
//        return "login";
//    }
//
//    @PostMapping("/login")
//    public String login(@RequestParam String login,
//                        @RequestParam String haslo,
//                        HttpSession session,
//                        Model model) {
//        System.out.println("START: Próba logowania - login=" + login + ", haslo (surowe)=" + haslo);
//
//        try {
//            Optional<Osoba> optionalOsoba = osobaRepository.findByLogin(login);
//            System.out.println("Czy użytkownik znaleziony? " + optionalOsoba.isPresent());
//
//            if (optionalOsoba.isPresent()) {
//                Osoba osoba = optionalOsoba.get();
//                System.out.println("Znaleziono: login=" + osoba.getLogin() + ", haslo z bazy=" + osoba.getHaslo());
//
//                boolean matches = passwordEncoder.matches(haslo, osoba.getHaslo());
//                System.out.println("Czy hasła pasują? " + matches);
//
//                if (matches) {
//                    session.setAttribute("loggedInUser", osoba);
//                    System.out.println("Logowanie UDANE - redirect do /admin");
//                    return "redirect:/admin";
//                } else {
//                    System.out.println("Hasła NIE pasują - dodaję błąd");
//                }
//            } else {
//                System.out.println("Użytkownik NIE znaleziony");
//            }
//
//            // Błąd - dodaj do modelu i wróć do login
//            model.addAttribute("error", "Nieprawidłowy login lub hasło");
//            System.out.println("END: Błąd logowania - wracam do login z błędem");
//            return "login";
//        } catch (Exception e) {
//            System.out.println("BŁĄD W LOGOWANIU: " + e.getMessage());
//            e.printStackTrace(); // Dodaj to, żeby zobaczyć pełny stack trace
//            return "redirect:/login"; // Awaryjny redirect
//        }
//    }
//
//    @GetMapping("/logout")
//    public String logout(HttpSession session) {
//        session.invalidate();
//        return "redirect:/login";
//    }
//}
