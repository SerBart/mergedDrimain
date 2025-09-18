package drimer.drimain.controller;

import drimer.drimain.model.Harmonogram;
import drimer.drimain.model.Maszyna;
import drimer.drimain.model.Osoba;
import drimer.drimain.repository.HarmonogramRepository;
import drimer.drimain.repository.MaszynaRepository;
import drimer.drimain.repository.OsobaRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;

@Controller
@RequestMapping("/harmonogramy")
public class HarmonogramController {

    @Autowired
    private HarmonogramRepository harmonogramRepository;
    @Autowired
    private MaszynaRepository maszynaRepository;
    @Autowired
    private OsobaRepository osobaRepository;

    @GetMapping
    public String harmonogramy(@RequestParam(required = false) Integer year,
                               @RequestParam(required = false) Integer month,
                               Model model,
                               Authentication authentication) {
        // Uprawnienia: tylko ADMIN i magazyn
        String username = authentication.getName();
        boolean isAdmin = authentication.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN"));
        if (!isAdmin && !"magazyn".equals(username)) {
            return "access-denied";
        }

        // Ustal miesiąc/rok
        YearMonth ym = YearMonth.now();
        if (year != null && month != null) {
            ym = YearMonth.of(year, month);
        }
        int daysInMonth = ym.lengthOfMonth();
        LocalDate firstDay = ym.atDay(1);
        LocalDate lastDay = ym.atEndOfMonth();

        int firstDayOfWeek = firstDay.getDayOfWeek().getValue(); // Pon=1, Nd=7
        int weeksCount = (int) Math.ceil((daysInMonth + firstDayOfWeek - 1) / 7.0);

        // Nawigacja
        int prevMonth = ym.getMonthValue() == 1 ? 12 : ym.getMonthValue() - 1;
        int prevYear = ym.getMonthValue() == 1 ? ym.getYear() - 1 : ym.getYear();
        int nextMonth = ym.getMonthValue() == 12 ? 1 : ym.getMonthValue() + 1;
        int nextYear = ym.getMonthValue() == 12 ? ym.getYear() + 1 : ym.getYear();

        // Dane do widoku
        List<Harmonogram> harmonogramy = harmonogramRepository.findByDataBetween(firstDay, lastDay);
        model.addAttribute("year", ym.getYear());
        model.addAttribute("month", ym.getMonthValue());
        model.addAttribute("daysInMonth", daysInMonth);
        model.addAttribute("weeksCount", weeksCount);
        model.addAttribute("firstDayOfWeek", firstDayOfWeek);
        model.addAttribute("prevMonth", prevMonth);
        model.addAttribute("prevYear", prevYear);
        model.addAttribute("nextMonth", nextMonth);
        model.addAttribute("nextYear", nextYear);
        model.addAttribute("harmonogramy", harmonogramy);
        model.addAttribute("maszyny", maszynaRepository.findAll());
        model.addAttribute("osoby", osobaRepository.findAll());
        return "harmonogramy";
    }

    @GetMapping("/nowy")
    public String nowyHarmonogramForm(Model model) {
        model.addAttribute("harmonogram", new Harmonogram());
        model.addAttribute("maszyny", maszynaRepository.findAll());
        model.addAttribute("osoby", osobaRepository.findAll());
        return "harmonogram-form :: addForm";
    }

    @PostMapping("/dodaj")
    public String dodajHarmonogram(@ModelAttribute Harmonogram harmonogram) {
        harmonogramRepository.save(harmonogram);
        return "redirect:/harmonogramy";
    }

    @GetMapping("/edytuj/{id}")
    public String edytujHarmonogramForm(@PathVariable Long id, Model model) {
        Harmonogram harmonogram = harmonogramRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Nie znaleziono harmonogramu"));
        model.addAttribute("harmonogram", harmonogram);
        model.addAttribute("maszyny", maszynaRepository.findAll());
        model.addAttribute("osoby", osobaRepository.findAll());
        return "harmonogram-form :: editForm";
    }

    @PostMapping("/edit")
    public String saveEditedHarmonogram(@ModelAttribute Harmonogram harmonogram) {
        harmonogramRepository.save(harmonogram);
        return "redirect:/harmonogramy";
    }

    @PostMapping("/delete")
    public String deleteHarmonogram(@RequestParam Long id) {
        harmonogramRepository.deleteById(id);
        return "redirect:/harmonogramy";
    }
}