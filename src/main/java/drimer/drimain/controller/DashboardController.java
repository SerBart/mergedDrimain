//package drimer.drimain.controller;
//
//import drimer.drimain.model.Osoba;
//import org.springframework.stereotype.Controller;
//import org.springframework.ui.Model;
//import org.springframework.web.bind.annotation.GetMapping;
//import jakarta.servlet.http.HttpSession;
//
//@Controller
//public class DashboardController {
//
//    @GetMapping("/dashboard")
//    public String dashboard(Model model, HttpSession session) {
//        System.out.println("=== DEBUG DASHBOARD ===");
//
//        if (session.getAttribute("loggedInUser") == null) {
//            System.out.println("Brak loggedInUser w sesji!");
//            return "redirect:/login";
//        }
//
//        Osoba loggedUser = (Osoba) session.getAttribute("loggedInUser");
//        System.out.println("Zalogowany user: " + loggedUser.getLogin() + ", rola: " + loggedUser.getRola());
//
//        model.addAttribute("loggedUser", loggedUser);
//        model.addAttribute("userRole", loggedUser.getRola());  // ← KLUCZOWE!
//        model.addAttribute("isLoggedIn", true);
//
//        return "redirect:/dashboard";
//    }
//
//}
