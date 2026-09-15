package drimer.drimain.controller;

import drimer.drimain.api.dto.PartCreateRequest;
import drimer.drimain.api.dto.PartDTO;
import drimer.drimain.api.dto.PartExcelImportResultDTO;
import drimer.drimain.api.dto.PartQuantityPatch;
import drimer.drimain.api.dto.PartUpdateRequest;
import drimer.drimain.model.Maszyna;
import drimer.drimain.model.Part;
import drimer.drimain.repository.MaszynaRepository;
import drimer.drimain.repository.PartRepository;
import drimer.drimain.repository.UserRepository;
import drimer.drimain.service.PartExcelImportService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
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

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

@Slf4j
@RestController
@RequestMapping({"/api/czesci", "/api/parts"})
@RequiredArgsConstructor
public class PartRestController {

    private static final String PRICE_MODULE = "CzesciCena";

    private final PartRepository partRepository;
    private final MaszynaRepository maszynaRepository;
    private final UserRepository userRepository;
    private final PartExcelImportService partExcelImportService;

    @GetMapping
    public List<PartDTO> list(@RequestParam Optional<String> kat,
                              @RequestParam Optional<String> q,
                              @RequestParam Optional<Boolean> belowMin,
                              Authentication authentication) {
        final boolean canSeePrice = canAccessPrice(authentication);
        return partRepository.findAll().stream()
                .filter(p -> kat.map(k -> k.equalsIgnoreCase(Optional.ofNullable(p.getKategoria()).orElse(""))).orElse(true))
                .filter(p -> q.map(query -> {
                    String qq = query.toLowerCase();
                    return (p.getNazwa() != null && p.getNazwa().toLowerCase().contains(qq))
                            || (p.getKod() != null && p.getKod().toLowerCase().contains(qq))
                            || (p.getKategoria() != null && p.getKategoria().toLowerCase().contains(qq));
                }).orElse(true))
                .filter(p -> belowMin.map(b -> !b || isBelowMin(p)).orElse(true))
                .map(p -> toDto(p, canSeePrice))
                .collect(Collectors.toList());
    }

    @GetMapping("/{id}")
    public PartDTO get(@PathVariable Long id, Authentication authentication) {
        Part p = partRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("Part not found"));
        return toDto(p, canAccessPrice(authentication));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public PartDTO create(@Valid @RequestBody PartCreateRequest req, Authentication authentication) {
        boolean canSeePrice = canAccessPrice(authentication);
        if (!canSeePrice && req.getCena() != null) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Brak uprawnień do ustawiania ceny części.");
        }

        Part p = new Part();
        p.setNazwa(req.getNazwa());
        p.setKod(req.getKod());
        p.setKategoria(req.getKategoria());
        p.setDataZakupu(req.getDataZakupu());
        p.setDataRealizacji(req.getDataRealizacji());
        if (canSeePrice) {
            p.setCena(req.getCena());
        }

        int startIlosc = req.getIlosc() != null ? req.getIlosc() : 0;
        if (startIlosc < 0) startIlosc = 0;
        p.setIlosc(startIlosc);

        int min = req.getMinIlosc() != null ? req.getMinIlosc() : 0;
        if (min < 0) min = 0;
        p.setMinIlosc(min);

        p.setJednostka(req.getJednostka());
        Part saved = partRepository.save(p);
        return toDto(saved, canSeePrice);
    }

    @PutMapping("/{id}")
    public PartDTO update(@PathVariable Long id, @Valid @RequestBody PartUpdateRequest req, Authentication authentication) {
        boolean canSeePrice = canAccessPrice(authentication);
        if (!canSeePrice && req.getCena() != null) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Brak uprawnień do ustawiania ceny części.");
        }

        Part p = partRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("Part not found"));
        if (req.getNazwa() != null) p.setNazwa(req.getNazwa());
        if (req.getKod() != null) p.setKod(req.getKod());
        if (req.getKategoria() != null) p.setKategoria(req.getKategoria());
        if (req.getDataZakupu() != null) p.setDataZakupu(req.getDataZakupu());
        if (req.getDataRealizacji() != null) p.setDataRealizacji(req.getDataRealizacji());
        if (canSeePrice && req.getCena() != null) p.setCena(req.getCena());
        if (req.getMinIlosc() != null) {
            int min = req.getMinIlosc();
            if (min < 0) min = 0;
            p.setMinIlosc(min);
        }
        if (req.getJednostka() != null) p.setJednostka(req.getJednostka());
        if (req.getMaszynaId() != null) {
            if (req.getMaszynaId() <= 0) {
                p.setMaszyna(null);
            } else {
                Maszyna m = maszynaRepository.findById(req.getMaszynaId()).orElse(null);
                p.setMaszyna(m);
            }
        }
        partRepository.save(p);
        return toDto(p, canSeePrice);
    }

    @PatchMapping("/{id}/ilosc")
    public PartDTO adjust(@PathVariable Long id, @RequestBody PartQuantityPatch patch, Authentication authentication) {
        Part p = partRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("Part not found"));
        int current = p.getIlosc() != null ? p.getIlosc() : 0;
        int delta = patch.getDelta() != null ? patch.getDelta() : 0;
        int updated = current + delta;
        if (updated < 0) updated = 0;
        p.setIlosc(updated);
        partRepository.save(p);
        return toDto(p, canAccessPrice(authentication));
    }

    @PatchMapping("/{id}/maszyna")
    public PartDTO assignToMaszyna(@PathVariable Long id,
                                   @RequestBody Map<String, Object> body,
                                   Authentication authentication) {
        Part p = partRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("Part not found"));
        Long maszynaId = null;
        Object raw = body == null ? null : body.get("maszynaId");
        if (raw instanceof Number n) {
            maszynaId = n.longValue();
        }

        if (maszynaId == null || maszynaId <= 0) {
            p.setMaszyna(null);
        } else {
            Maszyna m = maszynaRepository.findById(maszynaId).orElse(null);
            p.setMaszyna(m);
        }
        partRepository.save(p);
        return toDto(p, canAccessPrice(authentication));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        partRepository.deleteById(id);
    }

    @PostMapping(path = "/import", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public PartExcelImportResultDTO importExcel(@RequestPart("file") MultipartFile file) {
        try {
            return partExcelImportService.importFile(file);
        } catch (IllegalArgumentException ex) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, ex.getMessage(), ex);
        }
    }

    @GetMapping(value = "/export", produces = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    public ResponseEntity<byte[]> exportExcel() {
        byte[] content = partExcelImportService.exportFile(partRepository.findAll());
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.parseMediaType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"));
        headers.setContentDisposition(ContentDisposition.attachment().filename("czesci.xlsx").build());
        return new ResponseEntity<>(content, headers, HttpStatus.OK);
    }

    private boolean canAccessPrice(Authentication authentication) {
        if (authentication == null || authentication.getName() == null) return false;

        boolean isAdmin = authentication.getAuthorities().stream()
                .anyMatch(a -> "ROLE_ADMIN".equalsIgnoreCase(a.getAuthority()));
        if (isAdmin) return true;

        return userRepository.findByUsername(authentication.getName())
                .map(u -> u.getModules().stream().anyMatch(m -> PRICE_MODULE.equalsIgnoreCase(m)))
                .orElse(false);
    }

    private boolean isBelowMin(Part p) {
        return p.getIlosc() != null && p.getMinIlosc() != null && p.getIlosc() < p.getMinIlosc();
    }

    private PartDTO toDto(Part p, boolean includePrice) {
        PartDTO dto = new PartDTO();
        dto.setId(p.getId());
        dto.setNazwa(p.getNazwa());
        dto.setKod(p.getKod());
        dto.setOpis(p.getOpis());
        dto.setKategoria(p.getKategoria());
        dto.setIlosc(p.getIlosc());
        dto.setMinIlosc(p.getMinIlosc());
        dto.setJednostka(p.getJednostka());
        dto.setDataZakupu(p.getDataZakupu());
        dto.setDataRealizacji(p.getDataRealizacji());
        dto.setCena(includePrice ? p.getCena() : null);
        if (p.getMaszyna() != null) {
            dto.setMaszynaId(p.getMaszyna().getId());
            dto.setMaszynaNazwa(p.getMaszyna().getNazwa());
        }
        return dto;
    }
}
