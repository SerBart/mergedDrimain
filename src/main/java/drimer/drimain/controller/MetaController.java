package drimer.drimain.controller;

import drimer.drimain.model.enums.RaportStatus;
import drimer.drimain.model.enums.ZgloszenieStatus;
import org.springframework.web.bind.annotation.*;

import java.util.Arrays;
import java.util.List;
import java.util.HashSet;
import java.util.Set;

import lombok.RequiredArgsConstructor;
import drimer.drimain.repository.MaszynaRepository;
import drimer.drimain.repository.OsobaRepository;
import drimer.drimain.api.dto.SimpleMaszynaDTO;
import drimer.drimain.api.dto.SimpleOsobaDTO;
import drimer.drimain.repository.DzialRepository;
import drimer.drimain.api.dto.DzialDTO;
import drimer.drimain.api.dto.MaszynaSelectDTO;
import drimer.drimain.repository.UserRepository;
import drimer.drimain.model.Osoba;

@RestController
@RequestMapping("/api/meta")
@RequiredArgsConstructor
public class MetaController {

    private final MaszynaRepository maszynaRepository;
    private final OsobaRepository osobaRepository;
    private final DzialRepository dzialRepository;
    private final UserRepository userRepository;

    @GetMapping("/statusy/raporty")
    public List<String> raportStatuses() {
        return Arrays.stream(RaportStatus.values()).map(Enum::name).toList();
    }

    @GetMapping("/statusy/zgloszenia")
    public List<String> zgloszenieStatuses() {
        return Arrays.stream(ZgloszenieStatus.values()).map(Enum::name).toList();
    }

    // Proste listy do formularzy (bez ograniczenia do ADMIN)
    @GetMapping("/maszyny-simple")
    public List<SimpleMaszynaDTO> simpleMaszyny() {
        return maszynaRepository.findAll().stream().map(m -> {
            SimpleMaszynaDTO dto = new SimpleMaszynaDTO();
            dto.setId(m.getId());
            dto.setNazwa(m.getNazwa());
            return dto;
        }).toList();
    }

    @GetMapping("/osoby-simple")
    public List<SimpleOsobaDTO> simpleOsoby() {
        // Zbierz istniej05ce loginy Osob
        Set<String> existing = new HashSet<>();
        osobaRepository.findAll().forEach(o -> {
            if (o.getLogin() != null && !o.getLogin().isBlank()) existing.add(o.getLogin());
        });
        // Dla kacdego ucytkownika bez odpowiadaj05cej Osoby - utw7rz wpis Osoba (login=username)
        userRepository.findAll().forEach(u -> {
            String uname = u.getUsername();
            if (uname != null && !uname.isBlank() && !existing.contains(uname)) {
                Osoba nowa = new Osoba();
                nowa.setLogin(uname);
                // imie+nazwisko ustawiamy na username, dop5ki nie zostanie uzupe2nione inaczej
                nowa.setImieNazwisko(uname);
                nowa.setHaslo(null);
                nowa.setRola(null);
                osobaRepository.save(nowa);
                existing.add(uname);
            }
        });
        // Zwr057 gotow05 list19
        return osobaRepository.findAll().stream().map(o -> {
            SimpleOsobaDTO dto = new SimpleOsobaDTO();
            dto.setId(o.getId());
            dto.setImieNazwisko(o.getImieNazwisko());
            return dto;
        }).toList();
    }

    @GetMapping("/dzialy-simple")
    public List<DzialDTO> simpleDzialy() {
        return dzialRepository.findAll().stream().map(d -> {
            DzialDTO dto = new DzialDTO();
            dto.setId(d.getId());
            dto.setNazwa(d.getNazwa());
            return dto;
        }).toList();
    }

    // Alias: lista maszyn w formacie kompatybilnym z UI select (id, name, label, nazwa)
    @GetMapping("/maszyny")
    public java.util.List<MaszynaSelectDTO> maszyny() {
        return maszynaRepository.findAll().stream().map(m -> {
            MaszynaSelectDTO dto = new MaszynaSelectDTO();
            dto.setId(m.getId());
            dto.setNazwa(m.getNazwa());
            dto.setName(m.getNazwa());
            dto.setLabel(m.getNazwa());
            return dto;
        }).toList();
    }
}