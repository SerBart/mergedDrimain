package drimer.drimain.controller;

import drimer.drimain.api.dto.*;
import drimer.drimain.model.Part; // TODO: encja części
import drimer.drimain.repository.PartRepository; // TODO
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/czesci")
@RequiredArgsConstructor
public class PartRestController {

    private final PartRepository partRepository;

    @GetMapping
    public List<PartDTO> list(@RequestParam Optional<String> kat,
                              @RequestParam Optional<String> q,
                              @RequestParam Optional<Boolean> belowMin) {
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
        Part p = partRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("Part not found"));
        return toDto(p);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public PartDTO create(@RequestBody PartCreateRequest req) {
        Part p = new Part();
        p.setNazwa(req.getNazwa());
        p.setKod(req.getKod());
        p.setKategoria(req.getKategoria());
        p.setIlosc(req.getIlosc());
        p.setMinIlosc(req.getMinIlosc());
        p.setJednostka(req.getJednostka());
        partRepository.save(p);
        return toDto(p);
    }

    @PutMapping("/{id}")
    public PartDTO update(@PathVariable Long id, @RequestBody PartUpdateRequest req) {
        Part p = partRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("Part not found"));
        if (req.getNazwa() != null) p.setNazwa(req.getNazwa());
        if (req.getKod() != null) p.setKod(req.getKod());
        if (req.getKategoria() != null) p.setKategoria(req.getKategoria());
        if (req.getMinIlosc() != null) p.setMinIlosc(req.getMinIlosc());
        if (req.getJednostka() != null) p.setJednostka(req.getJednostka());
        partRepository.save(p);
        return toDto(p);
    }

    @PatchMapping("/{id}/ilosc")
    public PartDTO adjust(@PathVariable Long id, @RequestBody PartQuantityPatch patch) {
        Part p = partRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("Part not found"));
        p.setIlosc(p.getIlosc() + patch.getDelta());
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
        return dto;
    }
}