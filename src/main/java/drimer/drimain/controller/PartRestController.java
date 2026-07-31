package drimer.drimain.controller;

import drimer.drimain.api.dto.*;
import drimer.drimain.model.Maszyna;
import drimer.drimain.model.Part; // TODO: encja części
import drimer.drimain.repository.MaszynaRepository;
import drimer.drimain.repository.PartRepository; // TODO
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

/**
 * REST Controller for Parts (Części) management.
 * Handles CRUD operations for spare parts catalog.
 */
@Slf4j
@RestController
@RequestMapping({"/api/czesci", "/api/parts"})
@RequiredArgsConstructor
public class PartRestController {

    private final PartRepository partRepository;
    private final MaszynaRepository maszynaRepository;

    @GetMapping
    public List<PartDTO> list(@RequestParam Optional<String> kat,
                              @RequestParam Optional<String> q,
                              @RequestParam Optional<Boolean> belowMin) {
        log.debug("Listing parts with filters: kat={}, q={}, belowMin={}", kat, q, belowMin);
        return partRepository.findAll().stream()
                .filter(p -> kat.map(k -> k.equalsIgnoreCase(p.getKategoria())).orElse(true))
                .filter(p -> q.map(query ->
                        (p.getNazwa() != null && p.getNazwa().toLowerCase().contains(query.toLowerCase())) ||
                        (p.getKod() != null && p.getKod().toLowerCase().contains(query.toLowerCase())) ||
                        (p.getKategoria() != null && p.getKategoria().toLowerCase().contains(query.toLowerCase()))
                ).orElse(true))
                .filter(p -> belowMin.map(b -> !b || (p.getIlosc() != null && p.getMinIlosc() != null && p.getIlosc() < p.getMinIlosc())).orElse(true))
                .map(this::toDto)
                .collect(Collectors.toList());
    }

    @GetMapping("/{id}")
    public PartDTO get(@PathVariable Long id) {
        log.debug("Fetching part with id={}", id);
        Part p = partRepository.findById(id).orElseThrow(() -> {
            log.warn("Part not found with id={}", id);
            return new IllegalArgumentException("Part not found");
        });
        return toDto(p);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public PartDTO create(@Valid @RequestBody PartCreateRequest req) {
        log.info("Creating new part: {}", req.getNazwa());
        Part p = new Part();
        p.setNazwa(req.getNazwa());
        p.setKod(req.getKod());
        p.setKategoria(req.getKategoria());
        // normalizacja: ilości nie mogą być ujemne
        Integer startIlosc = req.getIlosc() != null ? req.getIlosc() : 0;
        if (startIlosc < 0) startIlosc = 0;
        p.setIlosc(startIlosc);
        Integer min = req.getMinIlosc() != null ? req.getMinIlosc() : 0;
        if (min < 0) min = 0;
        p.setMinIlosc(min);
        p.setJednostka(req.getJednostka());
        Part saved = partRepository.save(p);
        log.info("Part created successfully with id={}", saved.getId());
        return toDto(saved);
    }

    @PutMapping("/{id}")
    public PartDTO update(@PathVariable Long id, @Valid @RequestBody PartUpdateRequest req) {
        log.info("Updating part with id={}", id);
        Part p = partRepository.findById(id).orElseThrow(() -> {
            log.warn("Part not found with id={}", id);
            return new IllegalArgumentException("Part not found");
        });
        if (req.getNazwa() != null) p.setNazwa(req.getNazwa());
        if (req.getKod() != null) p.setKod(req.getKod());
        if (req.getKategoria() != null) p.setKategoria(req.getKategoria());
        if (req.getMinIlosc() != null) {
            int min = req.getMinIlosc();
            if (min < 0) min = 0;
            p.setMinIlosc(min);
        }
        if (req.getJednostka() != null) p.setJednostka(req.getJednostka());
        if (req.getMaszynaId() != null) {
            if (req.getMaszynaId() <= 0) {
                p.setMaszyna(null); // grupa "Inne"
            } else {
                Maszyna m = maszynaRepository.findById(req.getMaszynaId()).orElse(null);
                p.setMaszyna(m);
            }
        }
        partRepository.save(p);
        return toDto(p);
    }

    @PatchMapping("/{id}/ilosc")
    public PartDTO adjust(@PathVariable Long id, @RequestBody PartQuantityPatch patch) {
        Part p = partRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("Part not found"));
        int current = p.getIlosc() != null ? p.getIlosc() : 0;
        int delta = patch.getDelta() != null ? patch.getDelta() : 0;
        int updated = current + delta;
        if (updated < 0) updated = 0; // nie schodzimy poniżej zera
        p.setIlosc(updated);
        partRepository.save(p);
        return toDto(p);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        partRepository.deleteById(id);
    }

    private PartDTO toDto(Part p) {
        PartDTO dto = new PartDTO();
        dto.setId(p.getId());
        dto.setNazwa(p.getNazwa());
        dto.setKod(p.getKod());
        dto.setKategoria(p.getKategoria());
        dto.setIlosc(p.getIlosc());
        dto.setMinIlosc(p.getMinIlosc());
        dto.setJednostka(p.getJednostka());
        if (p.getMaszyna() != null) {
            dto.setMaszynaId(p.getMaszyna().getId());
            dto.setMaszynaNazwa(p.getMaszyna().getNazwa());
        }
        return dto;
    }
}