package drimer.drimain.controller;

import drimer.drimain.api.dto.*;
import drimer.drimain.model.Harmonogram;
import drimer.drimain.model.Maszyna;
import drimer.drimain.model.Osoba;
import drimer.drimain.model.NotificationType;
import drimer.drimain.service.NotificationService;
import drimer.drimain.model.enums.StatusHarmonogramu;
import drimer.drimain.repository.HarmonogramRepository;
import drimer.drimain.repository.DzialRepository;
import drimer.drimain.repository.MaszynaRepository;
import drimer.drimain.repository.OsobaRepository;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

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
    private final DzialRepository dzialRepository;
    // notification service
    private final NotificationService notificationService;

    @GetMapping
    public List<HarmonogramDTO> list(@RequestParam Optional<Integer> year,
                                   @RequestParam Optional<Integer> month) {
        List<Harmonogram> entities;
        if (year.isPresent()) {
            int y = year.get();
            java.time.LocalDate start;
            java.time.LocalDate end;
            if (month.isPresent()) {
                int m = month.get();
                start = java.time.LocalDate.of(y, m, 1);
                end = start.withDayOfMonth(start.lengthOfMonth());
            } else {
                start = java.time.LocalDate.of(y, 1, 1);
                end = java.time.LocalDate.of(y, 12, 31);
            }
            entities = harmonogramRepository.findByDataBetweenWithJoins(start, end);
        } else {
            entities = harmonogramRepository.findAllWithJoins();
        }
        return entities.stream()
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
    public HarmonogramDTO create(@Valid @RequestBody HarmonogramCreateRequest req) {
        Harmonogram h = new Harmonogram();
        h.setData(req.getData());
        h.setOpis(req.getOpis());
        h.setDurationMinutes(req.getDurationMinutes());

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
        if (req.getDzialId() != null) {
            h.setDzial(dzialRepository.findById(req.getDzialId())
                .orElseThrow(() -> new IllegalArgumentException("Dzial not found")));
        }
        if (req.getFrequency() != null) {
            h.setFrequency(req.getFrequency());
        }

        harmonogramRepository.save(h);

        // create module notification for harmonogramy
        try {
            String title = "Nowy harmonogram";
            String message = h.getOpis() != null ? h.getOpis() : "";
            String link = "/harmonogramy/" + h.getId();
            notificationService.createModuleNotification("Harmonogramy", NotificationType.NEW_HARMONOGRAM, title, message, link);
        } catch (Exception ex) {
            // ignore notification errors
        }

        return toDto(h);
    }

    @PutMapping("/{id}")
    public HarmonogramDTO update(@PathVariable Long id, @Valid @RequestBody HarmonogramUpdateRequest req) {
        Harmonogram h = harmonogramRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Harmonogram not found"));
        
        if (req.getData() != null) h.setData(req.getData());
        if (req.getOpis() != null) h.setOpis(req.getOpis());
        if (req.getDurationMinutes() != null) h.setDurationMinutes(req.getDurationMinutes());

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
        if (req.getDzialId() != null) {
            h.setDzial(dzialRepository.findById(req.getDzialId())
                .orElseThrow(() -> new IllegalArgumentException("Dzial not found")));
        }
        if (req.getFrequency() != null) {
            h.setFrequency(req.getFrequency());
        }

        harmonogramRepository.save(h);
        return toDto(h);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        harmonogramRepository.deleteById(id);
    }

    private HarmonogramDTO toDto(Harmonogram h) {
        HarmonogramDTO dto = new HarmonogramDTO();
        dto.setId(h.getId());
        dto.setData(h.getData());
        dto.setOpis(h.getOpis());
        dto.setStatus(h.getStatus());
        dto.setDurationMinutes(h.getDurationMinutes());
        dto.setFrequency(h.getFrequency());
        if (h.getDzial() != null) {
            SimpleDzialDTO dzDto = new SimpleDzialDTO();
            dzDto.setId(h.getDzial().getId());
            dzDto.setNazwa(h.getDzial().getNazwa());
            dto.setDzial(dzDto);
        }

        if (h.getMaszyna() != null) {
            SimpleMaszynaDTO maszynaDto = new SimpleMaszynaDTO();
            maszynaDto.setId(h.getMaszyna().getId());
            maszynaDto.setNazwa(h.getMaszyna().getNazwa());
            dto.setMaszyna(maszynaDto);
        }
        
        if (h.getOsoba() != null) {
            SimpleOsobaDTO osobaDto = new SimpleOsobaDTO();
            osobaDto.setId(h.getOsoba().getId());
            osobaDto.setImieNazwisko(h.getOsoba().getImieNazwisko());
            dto.setOsoba(osobaDto);
        }
        
        return dto;
    }
}