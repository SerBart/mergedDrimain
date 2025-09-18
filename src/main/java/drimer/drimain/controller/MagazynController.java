package drimer.drimain.controller;

import drimer.drimain.model.CzesciMagazyn;
import drimer.drimain.repository.CzesciMagazynRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;

@Controller
@RequestMapping("/magazyn")
public class MagazynController {
    @Autowired
    private CzesciMagazynRepository czesciMagazynRepository;

    @GetMapping
    public String magazyn(Model model, Authentication authentication) {
        // Dostęp tylko dla admin/magazyn
        String username = authentication.getName();
        boolean isAdmin = authentication.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN"));
        if (!isAdmin && !"magazyn".equals(username)) {
            return "access-denied";
        }
        model.addAttribute("czesci", czesciMagazynRepository.findAll());
        return "magazyn";
    }

    @GetMapping("/nowa")
    public String nowaCzescForm(Model model) {
        model.addAttribute("czesc", new CzesciMagazyn());
        return "magazyn-form :: addForm";
    }

    @PostMapping("/dodaj")
    public String dodajCzesc(@ModelAttribute CzesciMagazyn czesc) {
        czesc.setDataDodania(LocalDate.now());
        czesciMagazynRepository.save(czesc);
        return "redirect:/magazyn";
    }

    @GetMapping("/edytuj/{id}")
    public String edytujCzescForm(@PathVariable Long id, Model model) {
        var czesc = czesciMagazynRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("Nie znaleziono części"));
        model.addAttribute("czesc", czesc);
        return "magazyn-form :: editForm";
    }
    @PostMapping("/edit")
    public String saveEditedCzesc(@ModelAttribute CzesciMagazyn czesc) {
        czesciMagazynRepository.save(czesc);
        return "redirect:/magazyn";
    }

    @PostMapping("/delete")
    public String deleteCzesc(@RequestParam Long id) {
        czesciMagazynRepository.deleteById(id);
        return "redirect:/magazyn";
    }
}