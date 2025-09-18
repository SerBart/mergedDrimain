package drimer.drimain.controller;

import drimer.drimain.model.Raport;
import drimer.drimain.model.enums.RaportStatus;
import drimer.drimain.repository.*;
import drimer.drimain.service.RaportService;
import drimer.drimain.util.RaportStatusMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

@Controller
public class RaportController {

    @Autowired private RaportService raportService;
    @Autowired private MaszynaRepository maszynaRepository;
    @Autowired private OsobaRepository osobaRepository;
    @Autowired private DzialRepository dzialRepository;
    @Autowired private RaportRepository raportRepository;

    @GetMapping("/raporty")
    public String raporty(Model model) {
        List<Raport> lista = raportRepository.findAll();
        model.addAttribute("raporty", lista);
        return "raporty";
    }

    @GetMapping("/raport/nowy")
    public String nowyRaportForm(Model model,
                                 @RequestParam(value = "fragment", defaultValue = "false") boolean fragment) {
        model.addAttribute("raport", new Raport());
        model.addAttribute("maszyny", maszynaRepository.findAll());
        model.addAttribute("osoby", osobaRepository.findAll());
        if (fragment) {
            return "raport-form :: addForm";
        }
        return "raport-form";
    }

    @GetMapping("/raport/edytuj/{id}")
    public String edytujRaportForm(@PathVariable Long id,
                                   Model model,
                                   @RequestParam(value = "fragment", defaultValue = "false") boolean fragment) {
        Raport raport = raportRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Invalid id"));
        model.addAttribute("raport", raport);
        model.addAttribute("maszyny", maszynaRepository.findAll());
        model.addAttribute("osoby", osobaRepository.findAll());
        if (fragment) {
            return "raporty :: editForm";
        }
        return "raport-form";
    }

    @PostMapping("/raport/zapisz")
    public String zapiszRaport(@RequestParam(required = false) Long id,
                               @RequestParam Long maszynaId,
                               @RequestParam String typNaprawy,
                               @RequestParam String opis,
                               @RequestParam Long osobaId,
                               @RequestParam String status,
                               @RequestParam String dataNaprawy,
                               @RequestParam String czasOd,
                               @RequestParam String czasDo) {

        Raport raport = id != null
                ? raportRepository.findById(id).orElse(new Raport())
                : new Raport();

        raport.setMaszyna(maszynaRepository.findById(maszynaId).orElse(null));
        raport.setTypNaprawy(typNaprawy);
        raport.setOpis(opis);
        raport.setOsoba(osobaRepository.findById(osobaId).orElse(null));

        RaportStatus mapped = RaportStatusMapper.map(status);
        if (mapped == null) {
            // fallback – ustaw NOWY albo rzuć wyjątek
            mapped = RaportStatus.NOWY;
        }
        raport.setStatus(mapped);

        raport.setDataNaprawy(LocalDate.parse(dataNaprawy));
        raport.setCzasOd(LocalTime.parse(czasOd));
        raport.setCzasDo(LocalTime.parse(czasDo));

        raportRepository.save(raport);
        return "redirect:/raporty";
    }

    @GetMapping("/raport/usun/{id}")
    public String usunRaport(@PathVariable Long id) {
        raportService.delete(id);
        return "redirect:/raporty";
    }

    @PostMapping("/raport/delete")
    public String deleteRaport(@RequestParam Long id) {
        raportService.delete(id);
        return "redirect:/raporty";
    }
}