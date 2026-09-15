jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import drimer.drimain.api.dto.PartCreateRequest;
import drimer.drimain.api.dto.PartDTO;
import drimer.drimain.api.dto.PartExcelImportResultDTO;
import drimer.drimain.api.dto.PartQuantityPatch;
import drimer.drimain.api.dto.PartUpdateRequest;
import org.springframework.http.HttpStatus;
import drimer.drimain.model.Part;

import drimer.drimain.repository.PartRepository;
import drimer.drimain.service.PartExcelImportService;
import java.util.Optional;
import java.util.stream.Collectors;

/**
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;
 * Handles CRUD operations for spare parts catalog.
 */
@Slf4j
@RestController
@RequestMapping({"/api/czesci", "/api/parts"})
    private final MaszynaRepository maszynaRepository;

    @GetMapping
    public List<PartDTO> list(@RequestParam Optional<String> kat,
                              @RequestParam Optional<String> q,
                              @RequestParam Optional<Boolean> belowMin) {
        log.debug("Listing parts with filters: kat={}, q={}, belowMin={}", kat, q, belowMin);
        return partRepository.findAll().stream()
    private final PartExcelImportService partExcelImportService;
                .filter(p -> kat.map(k -> k.equalsIgnoreCase(p.getKategoria())).orElse(true))
                .filter(p -> q.map(query ->
                        (p.getNazwa() != null && p.getNazwa().toLowerCase().contains(query.toLowerCase())) ||
                        (p.getKod() != null && p.getKod().toLowerCase().contains(query.toLowerCase())) ||
                        (p.getKategoria() != null && p.getKategoria().toLowerCase().contains(query.toLowerCase()))
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
        Part p = partRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("Part not found"));
        Part p = new Part();
        p.setNazwa(req.getNazwa());
        p.setKod(req.getKod());
        p.setKategoria(req.getKategoria());
        // normalizacja: ilości nie mogą być ujemne
        Integer startIlosc = req.getIlosc() != null ? req.getIlosc() : 0;
        p.setIlosc(startIlosc);
        Integer min = req.getMinIlosc() != null ? req.getMinIlosc() : 0;
        if (min < 0) min = 0;
        p.setMinIlosc(min);

        int startIlosc = req.getIlosc() != null ? req.getIlosc() : 0;
        log.info("Part created successfully with id={}", saved.getId());
        return toDto(saved);

        int min = req.getMinIlosc() != null ? req.getMinIlosc() : 0;

    @PutMapping("/{id}")

    public PartDTO update(@PathVariable Long id, @Valid @RequestBody PartUpdateRequest req) {
        log.info("Updating part with id={}", id);
            log.warn("Part not found with id={}", id);
            return new IllegalArgumentException("Part not found");
        });
        if (req.getNazwa() != null) p.setNazwa(req.getNazwa());
        if (req.getKod() != null) p.setKod(req.getKod());
        Part p = partRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("Part not found"));
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
                p.setMaszyna(null);
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
        if (updated < 0) updated = 0;
    public void delete(@PathVariable Long id) {
        partRepository.deleteById(id);    @PostMapping(path = "/import", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public PartExcelImportResultDTO importExcel(@RequestPart("file") MultipartFile file) {
        try {
            return partExcelImportService.importFile(file);
        } catch (IllegalArgumentException ex) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, ex.getMessage(), ex);
        }
    }

        dto.setNazwa(p.getNazwa());
        dto.setOpis(p.getOpis());

