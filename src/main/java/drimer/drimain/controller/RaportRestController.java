package drimer.drimain.controller;

import drimer.drimain.api.dto.RaportCreateRequest;
import drimer.drimain.api.dto.RaportDTO;
import drimer.drimain.api.dto.RaportUpdateRequest;
import drimer.drimain.api.mapper.RaportMapper;
import drimer.drimain.events.RaportChangedEvent;
import drimer.drimain.model.Raport;
import drimer.drimain.model.enums.RaportStatus;
import drimer.drimain.repository.MaszynaRepository;
import drimer.drimain.repository.OsobaRepository;
import drimer.drimain.repository.RaportRepository;
import drimer.drimain.repository.spec.RaportSpecifications;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.*;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/raporty")
@RequiredArgsConstructor
public class RaportRestController {

    private final RaportRepository raportRepository;
    private final MaszynaRepository maszynaRepository;
    private final ApplicationEventPublisher publisher;
    private final OsobaRepository osobaRepository;
    private final RaportMapper raportMapper;

    @GetMapping
    public Page<RaportDTO> list(@RequestParam(required = false) String status,
                                @RequestParam(required = false) Long maszynaId,
                                @RequestParam(required = false) LocalDate from,
                                @RequestParam(required = false) LocalDate to,
                                @RequestParam(required = false) String q,
                                @RequestParam(defaultValue = "0") int page,
                                @RequestParam(defaultValue = "25") int size,
                                @RequestParam(defaultValue = "dataNaprawy,desc") String sort) {

        Sort sortObj = Sort.by(
            java.util.Arrays.stream(sort.split(","))
                .map(s -> {
                    String[] p = s.split(":");
                    String field = p[0];
                    Sort.Direction dir = p.length > 1 && p[1].equalsIgnoreCase("asc") ? Sort.Direction.ASC : Sort.Direction.DESC;
                    return new Sort.Order(dir, field);
                }).collect(Collectors.toList())
        );

        Pageable pageable = PageRequest.of(page, size, sortObj);

        RaportStatus statusEnum = null;
        if (status != null && !status.isBlank()) {
            try { statusEnum = RaportStatus.valueOf(status); } catch (Exception ignored) {}
        }

        Specification<Raport> spec =
                Specification.where(RaportSpecifications.hasStatus(statusEnum))
                        .and(RaportSpecifications.hasMaszynaId(maszynaId))
                        .and(RaportSpecifications.dateFrom(from))
                        .and(RaportSpecifications.dateTo(to))
                        .and(RaportSpecifications.fullText(q));

        Page<Raport> pageData = raportRepository.findAll(spec, pageable);
        return pageData.map(raportMapper::toDto);
    }

    @GetMapping("/{id}")
    public RaportDTO get(@PathVariable Long id) {
        Raport r = raportRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("Raport not found"));
        return raportMapper.toDto(r);
    }

    
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public RaportDTO create(@RequestBody RaportCreateRequest req) {
        Raport r = new Raport();
        r.setTypNaprawy(req.getTypNaprawy());
        r.setOpis(req.getOpis());
        raportMapper.applyCreateDefaults(r, req);
        r.setDataNaprawy(req.getDataNaprawy());
        if (req.getCzasOd() != null) r.setCzasOd(LocalTime.parse(req.getCzasOd()));
        if (req.getCzasDo() != null) r.setCzasDo(LocalTime.parse(req.getCzasDo()));
        if (req.getMaszynaId() != null)
            r.setMaszyna(maszynaRepository.findById(req.getMaszynaId()).orElse(null));
        if (req.getOsobaId() != null)
            r.setOsoba(osobaRepository.findById(req.getOsobaId()).orElse(null));
        if (req.getPartUsages() != null) {
            raportMapper.applyPartUsages(r, req.getPartUsages());
        }
        raportRepository.save(r);
        publisher.publishEvent(new RaportChangedEvent(this, raportMapper.toDto(r), "CREATED"));

        return raportMapper.toDto(r);
    }

    @PutMapping("/{id}")
    public RaportDTO update(@PathVariable Long id, @RequestBody RaportUpdateRequest req) {
        Raport r = raportRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("Raport not found"));
        if (req.getStatus() != null) {
            try { r.setStatus(RaportStatus.valueOf(req.getStatus())); } catch (Exception ignored) {}
        }
        raportMapper.updateEntity(r, req);
        raportRepository.save(r);
        publisher.publishEvent(new RaportChangedEvent(this, raportMapper.toDto(r), "UPDATED"));

        return raportMapper.toDto(r);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        raportRepository.deleteById(id);
    }
}