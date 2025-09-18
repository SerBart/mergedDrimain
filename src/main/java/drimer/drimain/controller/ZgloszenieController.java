package drimer.drimain.controller;

import drimer.drimain.model.Zgloszenie;
import drimer.drimain.repository.MaszynaRepository;
import drimer.drimain.repository.OsobaRepository;
import drimer.drimain.repository.ZgloszenieRepository;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.*;

import java.time.DateTimeException;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/**
 * Kontroler obsługujący CRUD dla zgłoszeń.
 * Ujednolicona obsługa błędów + podstawowa walidacja server-side.
 */
@Controller
@RequestMapping
public class ZgloszenieController {

    private final ZgloszenieRepository zgloszenieRepository;
    private final MaszynaRepository maszynaRepository;
    private final OsobaRepository osobaRepository;

    private static final DateTimeFormatter DATE_TIME_FMT = DateTimeFormatter.ISO_LOCAL_DATE_TIME;

    @Autowired
    public ZgloszenieController(ZgloszenieRepository zgloszenieRepository,
                                MaszynaRepository maszynaRepository,
                                OsobaRepository osobaRepository) {
        this.zgloszenieRepository = zgloszenieRepository;
        this.maszynaRepository = maszynaRepository;
        this.osobaRepository = osobaRepository;
    }

    // DTO aby nie wiązać bezpośrednio encji z formularzem
    public static class ZgloszenieForm {
        private Long id;

        @NotBlank(message = "Imię jest wymagane")
        private String imie;

        @NotBlank(message = "Nazwisko jest wymagane")
        private String nazwisko;

        @NotBlank(message = "Typ jest wymagany")
        private String typ;

        @NotBlank(message = "Opis jest wymagany")
        @Size(min = 10, message = "Opis musi mieć co najmniej 10 znaków")
        private String opis;

        @NotBlank(message = "Data i godzina są wymagane")
        // HTML datetime-local daje format yyyy-MM-ddTHH:mm (bez sekund) – ISO_LOCAL_DATE_TIME to akceptuje
        private String dataGodzina;

        public Long getId() { return id; }
        public void setId(Long id) { this.id = id; }
        public String getImie() { return imie; }
        public void setImie(String imie) { this.imie = imie; }
        public String getNazwisko() { return nazwisko; }
        public void setNazwisko(String nazwisko) { this.nazwisko = nazwisko; }
        public String getTyp() { return typ; }
        public void setTyp(String typ) { this.typ = typ; }
        public String getOpis() { return opis; }
        public void setOpis(String opis) { this.opis = opis; }
        public String getDataGodzina() { return dataGodzina; }
        public void setDataGodzina(String dataGodzina) { this.dataGodzina = dataGodzina; }
    }

    @GetMapping("/zgloszenia")
    public String listaZgloszen(Model model) {
        model.addAttribute("zgloszenia", zgloszenieRepository.findAll());
        model.addAttribute("maszyny", maszynaRepository.findAll());
        model.addAttribute("osoby", osobaRepository.findAll());
        model.addAttribute("form", new ZgloszenieForm());
        return "zgloszenia";
    }

    @PostMapping("/zgloszenie/zapisz")
    public String zapiszZgloszenie(@Valid @ModelAttribute("form") ZgloszenieForm form,
                                   BindingResult bindingResult,
                                   Model model) {
        // Walidacja bazowa
        if (bindingResult.hasErrors()) {
            prepareLists(model);
            model.addAttribute("error", "Formularz zawiera błędy – popraw je.");
            return "zgloszenia";
        }

        LocalDateTime dateTime;
        try {
            dateTime = LocalDateTime.parse(form.getDataGodzina(), DATE_TIME_FMT);
        } catch (DateTimeException ex) {
            prepareLists(model);
            model.addAttribute("error", "Błąd parsowania daty/godziny. Oczekiwany format: yyyy-MM-ddTHH:mm");
            return "zgloszenia";
        }

        Zgloszenie zgloszenie = (form.getId() != null)
                ? zgloszenieRepository.findById(form.getId()).orElse(new Zgloszenie())
                : new Zgloszenie();

        zgloszenie.setImie(form.getImie());
        zgloszenie.setNazwisko(form.getNazwisko());
        zgloszenie.setTyp(form.getTyp());
        zgloszenie.setOpis(form.getOpis());
        zgloszenie.setDataGodzina(dateTime);

        try {
            zgloszenie.validate(); // zakładam, że ta metoda istnieje w encji
        } catch (IllegalArgumentException ex) {
            prepareLists(model);
            model.addAttribute("error", "Walidacja nie powiodła się: " + ex.getMessage());
            return "zgloszenia";
        }

        zgloszenieRepository.save(zgloszenie);
        return "redirect:/zgloszenia";
    }

    @GetMapping("/zgloszenia/edit/{id}")
    public String editZgloszenie(@PathVariable Long id, Model model) {
        Zgloszenie z = zgloszenieRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Zgłoszenie o ID " + id + " nie istnieje"));
        ZgloszenieForm form = new ZgloszenieForm();
        form.setId(z.getId());
        form.setImie(z.getImie());
        form.setNazwisko(z.getNazwisko());
        form.setTyp(z.getTyp());
        form.setOpis(z.getOpis());
        form.setDataGodzina(z.getDataGodzina() != null ? z.getDataGodzina().format(DATE_TIME_FMT) : "");
        prepareLists(model);
        model.addAttribute("form", form);
        model.addAttribute("editMode", true);
        return "zgloszenia :: editFormFragment";
    }

    @GetMapping("/zgloszenia/delete/{id}")
    public String deleteZgloszenie(@PathVariable Long id, Model model) {
        if (!zgloszenieRepository.existsById(id)) {
            model.addAttribute("error", "Nie znaleziono zgłoszenia do usunięcia (ID: " + id + ")");
            return "redirect:/zgloszenia";
        }
        zgloszenieRepository.deleteById(id);
        return "redirect:/zgloszenia";
    }

    private void prepareLists(Model model) {
        model.addAttribute("maszyny", maszynaRepository.findAll());
        model.addAttribute("osoby", osobaRepository.findAll());
    }
}