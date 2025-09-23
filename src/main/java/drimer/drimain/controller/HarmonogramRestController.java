package drimer.drimain.controller;

import drimer.drimain.api.dto.*;
import drimer.drimain.model.Harmonogram;
import drimer.drimain.model.Maszyna;
import drimer.drimain.model.Osoba;
import drimer.drimain.model.enums.StatusHarmonogramu;
import drimer.drimain.repository.HarmonogramRepository;
import drimer.drimain.repository.MaszynaRepository;
import drimer.drimain.repository.OsobaRepository;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/harmonogramy")
@RequiredArgsConstructor
public class HarmonogramRestController {

    private final HarmonogramRepository harmonogramRepository;
    private final MaszynaRepository maszynaRepository;
    private final OsobaRepository osobaRepository;

    @GetMapping
    public List<HarmonogramDTO> list(@RequestParam Optional<LocalDate> start,
                                     @RequestParam Optional<LocalDate> end,
                                     @RequestParam Optional<String> q) {
        List<Harmonogram> src = (start.isPresent() && end.isPresent())
                ? harmonogramRepository.findByDataBetween(start.get(), end.get())
                : harmonogramRepository.findAll();

        return src.stream()
                .filter(h -> q.map(qq -> {
                    String s = qq.toLowerCase();
                    return (h.getOpis() != null && h.getOpis().toLowerCase().contains(s))
                            || (h.getMaszyna() != null && h.getMaszyna().getNazwa() != null
                            && h.getMaszyna().getNazwa().toLowerCase().contains(s))
                            || (h.getOsoba() != null && h.getOsoba().getImieNazwisko() != null
                            && h.getOsoba().getImieNazwisko().toLowerCase().contains(s));
                }).orElse(true))
                .map(this::toDto)
                .collect(Collectors.toList());
    }

    @GetMapping("/{id}")
    public HarmonogramDTO get(@PathVariable Long id) {
        Harmonogram h = harmonogramRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Harmonogram not found"));
        return toDto(h);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('ADMIN','BIURO')")
    public HarmonogramDTO create(@Valid @RequestBody HarmonogramCreateRequest req,
                                 Authentication authentication) {
        Harmonogram h = new Harmonogram();
        h.setData(req.getData());
        h.setOpis(req.getOpis());

        if (req.getMaszynaId() != null) {
            Maszyna maszyna = maszynaRepository.findById(req.getMaszynaId())
                    .orElseThrow(() -> new IllegalArgumentException("Maszyna not found"));
            h.setMaszyna(maszyna);
        }

        if (req.getOsobaId() != null) {
            Osoba osoba = osobaRepository.findById(req.getOsobaId())
                    .orElseThrow(() -> new IllegalArgumentException("Osoba not found"));
            h.setOsoba(osoba);
        }

        h.setStatus(req.getStatus() != null ? req.getStatus() : StatusHarmonogramu.PLANOWANE);
        harmonogramRepository.save(h);
        return toDto(h);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','BIURO')")
    public HarmonogramDTO update(@PathVariable Long id,
                                 @Valid @RequestBody HarmonogramUpdateRequest req,
                                 Authentication authentication) {
        Harmonogram h = harmonogramRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Harmonogram not found"));

        if (req.getData() != null) h.setData(req.getData());
        if (req.getOpis() != null) h.setOpis(req.getOpis());

        if (req.getMaszynaId() != null) {
            Maszyna maszyna = maszynaRepository.findById(req.getMaszynaId())
                    .orElseThrow(() -> new IllegalArgumentException("Maszyna not found"));
            h.setMaszyna(maszyna);
        }

        if (req.getOsobaId() != null) {
            Osoba osoba = osobaRepository.findById(req.getOsobaId())
                    .orElseThrow(() -> new IllegalArgumentException("Osoba not found"));
            h.setOsoba(osoba);
        }

        if (req.getStatus() != null) h.setStatus(req.getStatus());

        harmonogramRepository.save(h);
        return toDto(h);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAnyRole('ADMIN','BIURO')")
    public void delete(@PathVariable Long id, Authentication authentication) {
        harmonogramRepository.deleteById(id);
    }

    private HarmonogramDTO toDto(Harmonogram h) {
        HarmonogramDTO dto = new HarmonogramDTO();
        dto.setId(h.getId());
        dto.setData(h.getData());
        dto.setOpis(h.getOpis());
        dto.setStatus(h.getStatus());

        if (h.getMaszyna() != null) {
            SimpleMaszynaDTO m = new SimpleMaszynaDTO();
            m.setId(h.getMaszyna().getId());
            m.setNazwa(h.getMaszyna().getNazwa());
            dto.setMaszyna(m);
        }
        if (h.getOsoba() != null) {
            SimpleOsobaDTO o = new SimpleOsobaDTO();
            o.setId(h.getOsoba().getId());
            o.setImieNazwisko(h.getOsoba().getImieNazwisko());
            dto.setOsoba(o);
        }
        return dto;
    }
}