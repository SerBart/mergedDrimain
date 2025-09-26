package drimer.drimain.controller;

import drimer.drimain.model.enums.RaportStatus;
import drimer.drimain.model.enums.ZgloszenieStatus;
import org.springframework.web.bind.annotation.*;

import java.util.Arrays;
import java.util.List;

import lombok.RequiredArgsConstructor;
import drimer.drimain.repository.MaszynaRepository;
import drimer.drimain.repository.OsobaRepository;
import drimer.drimain.api.dto.SimpleMaszynaDTO;
import drimer.drimain.api.dto.SimpleOsobaDTO;

@RestController
@RequestMapping("/api/meta")
@RequiredArgsConstructor
public class MetaController {

    private final MaszynaRepository maszynaRepository;
    private final OsobaRepository osobaRepository;

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
        return osobaRepository.findAll().stream().map(o -> {
            SimpleOsobaDTO dto = new SimpleOsobaDTO();
            dto.setId(o.getId());
            dto.setImieNazwisko(o.getImieNazwisko());
            return dto;
        }).toList();
    }
}