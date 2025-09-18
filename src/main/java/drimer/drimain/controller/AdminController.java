package drimer.drimain.controller;

import drimer.drimain.model.*;
import drimer.drimain.repository.*;
import jakarta.servlet.http.HttpSession;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.annotation.Secured;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

import java.util.Optional;

@Controller
@RequestMapping("/admin")
@Secured("ROLE_ADMIN")
public class AdminController {

    @Autowired
    private MaszynaRepository maszynaRepository;

    @Autowired
    private OsobaRepository osobaRepository;

    @Autowired
    private DzialRepository dzialRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private BCryptPasswordEncoder passwordEncoder;

    // Panel admina
    @GetMapping("")
    public String adminPanel(Model model) {
        model.addAttribute("maszyny", maszynaRepository.findAll());
        model.addAttribute("osoby", osobaRepository.findAll());
        model.addAttribute("dzialy", dzialRepository.findAll());
        model.addAttribute("users", userRepository.findAll());
        model.addAttribute("newUser", new User());
        model.addAttribute("newMaszyna", new Maszyna());
        model.addAttribute("newOsoba", new Osoba());
        return "admin";
    }

    // Dodawanie działu
    @PostMapping("/dodaj-dzial")
    public String dodajDzial(@RequestParam String nazwa) {
        Dzial dzial = new Dzial();
        dzial.setNazwa(nazwa);
        dzialRepository.save(dzial);
        return "redirect:/admin";
    }

    // Usuwanie działu
    @PostMapping("/delete-dzial")
    public String deleteDzial(@RequestParam Long id) {
        dzialRepository.deleteById(id);
        return "redirect:/admin";
    }

    // Dodawanie maszyny
    @PostMapping("/dodaj-maszyna")
    public String dodajMaszyna(@RequestParam String nazwa, @RequestParam Long dzialId) {
        Optional<Dzial> optionalDzial = dzialRepository.findById(dzialId);
        if (optionalDzial.isEmpty()) {
            // Możesz obsłużyć błąd np. przez atrybut modelu
            return "redirect:/admin?error=dzialNotFound";
        }
        Maszyna maszyna = new Maszyna();
        maszyna.setNazwa(nazwa);
        maszyna.setDzial(optionalDzial.get());
        maszynaRepository.save(maszyna);
        return "redirect:/admin";
    }

    // Usuwanie maszyny
    @PostMapping("/delete-maszyna")
    public String deleteMaszyna(@RequestParam Long id) {
        maszynaRepository.deleteById(id);
        return "redirect:/admin";
    }

    // Dodawanie osoby
    @PostMapping("/dodaj-osoba")
    public String dodajOsoba(@RequestParam String imieNazwisko) {
        Osoba osoba = new Osoba();
        osoba.setImieNazwisko(imieNazwisko);
        osobaRepository.save(osoba);
        return "redirect:/admin";
    }

    // Usuwanie osoby
    @PostMapping("/delete-osoba")
    public String deleteOsoba(@RequestParam Long id) {
        osobaRepository.deleteById(id);
        return "redirect:/admin";
    }

    // Dodawanie użytkownika (User entity, nie Osoba)
    @Autowired private RoleRepository roleRepository;

    @PostMapping("/add-user")
    public String addUser(@ModelAttribute User newUser, @RequestParam String role) {
        newUser.setPassword(passwordEncoder.encode(newUser.getPassword()));
        newUser.clearRoles();
        Role r = roleRepository.findByName(role)
                .orElseThrow(() -> new IllegalArgumentException("Unknown role: " + role));
        newUser.addRole(r);
        userRepository.save(newUser);
        return "redirect:/admin";
    }
    // Usuwanie użytkownika
    @PostMapping("/delete-user")
    public String deleteUser(@RequestParam Long id) {
        userRepository.deleteById(id);
        return "redirect:/admin";
    }
}