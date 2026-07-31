package drimer.drimain.controller;

import drimer.drimain.api.dto.SimpleMaszynaDTO;
import drimer.drimain.api.dto.SimpleDzialDTO;
import drimer.drimain.api.dto.SimpleSekcjaDTO;
import drimer.drimain.api.dto.MaszynaSelectDTO;
import drimer.drimain.repository.MaszynaRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/maszyny")
@RequiredArgsConstructor
public class MaszynaRestController {

    private final MaszynaRepository maszynaRepository;

    // Dostępne dla zalogowanych (ROLE_USER wystarczy). Jeśli chcesz kompletnie publiczne, usuń PreAuthorize.
    @GetMapping
    @PreAuthorize("hasAnyRole('USER','ADMIN','BIURO','MAGAZYN')")
    public List<SimpleMaszynaDTO> list(@RequestParam Optional<String> q,
                                       @RequestParam Optional<Long> dzialId,
                                       @RequestParam Optional<Long> sekcjaId) {
        return maszynaRepository.findAll().stream()
                .filter(m -> q.map(s -> m.getNazwa() != null && m.getNazwa().toLowerCase().contains(s.toLowerCase())).orElse(true))
                .filter(m -> dzialId.map(id -> m.getDzial() != null && id.equals(m.getDzial().getId())).orElse(true))
                .filter(m -> sekcjaId.map(id -> m.getSekcja() != null && id.equals(m.getSekcja().getId())).orElse(true))
                .map(m -> {
                    SimpleMaszynaDTO dto = new SimpleMaszynaDTO();
                    dto.setId(m.getId());
                    dto.setNazwa(m.getNazwa());
                    if (m.getDzial() != null) {
                        SimpleDzialDTO d = new SimpleDzialDTO();
                        d.setId(m.getDzial().getId());
                        d.setNazwa(m.getDzial().getNazwa());
                        dto.setDzial(d);
                    }
                    if (m.getSekcja() != null) {
                        SimpleSekcjaDTO s = new SimpleSekcjaDTO();
                        s.setId(m.getSekcja().getId());
                        s.setNazwa(m.getSekcja().getNazwa());
                        dto.setSekcja(s);
                    }
                    return dto;
                })
                .collect(Collectors.toList());
    }

    @GetMapping("/select")
    @PreAuthorize("hasAnyRole('USER','ADMIN','BIURO','MAGAZYN')")
    public List<MaszynaSelectDTO> listForSelect(@RequestParam Optional<String> q,
                                                @RequestParam Optional<Long> dzialId,
                                                @RequestParam Optional<Long> sekcjaId) {
        return maszynaRepository.findAll().stream()
                .filter(m -> q.map(s -> m.getNazwa() != null && m.getNazwa().toLowerCase().contains(s.toLowerCase())).orElse(true))
                .filter(m -> dzialId.map(id -> m.getDzial() != null && id.equals(m.getDzial().getId())).orElse(true))
                .filter(m -> sekcjaId.map(id -> m.getSekcja() != null && id.equals(m.getSekcja().getId())).orElse(true))
                .map(m -> {
                    MaszynaSelectDTO dto = new MaszynaSelectDTO();
                    dto.setId(m.getId());
                    dto.setNazwa(m.getNazwa());
                    dto.setName(m.getNazwa());
                    dto.setLabel(m.getSekcja() != null ? m.getNazwa() + " [" + m.getSekcja().getNazwa() + "]" : m.getNazwa());
                    return dto;
                })
                .collect(java.util.stream.Collectors.toList());
    }
}
