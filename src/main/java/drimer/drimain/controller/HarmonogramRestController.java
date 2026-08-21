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
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/harmonogramy")
@RequiredArgsConstructor
public class HarmonogramRestController {

    private static final LocalDate DEFAULT_PLAN_END_DATE = LocalDate.of(2027, 12, 31);

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
    @Transactional
    public HarmonogramDTO create(@Valid @RequestBody HarmonogramCreateRequest req) {
        final Maszyna maszyna = req.getMaszynaId() != null
                ? maszynaRepository.findById(req.getMaszynaId())
                .orElseThrow(() -> new IllegalArgumentException("Maszyna not found"))
                : null;
        final Osoba osoba = req.getOsobaId() != null
                ? osobaRepository.findById(req.getOsobaId())
                .orElseThrow(() -> new IllegalArgumentException("Osoba not found"))
                : null;
        final var dzial = req.getDzialId() != null
                ? dzialRepository.findById(req.getDzialId())
                .orElseThrow(() -> new IllegalArgumentException("Dzial not found"))
                : null;

        LocalDate planEndDate = req.getPlanEndDate() != null ? req.getPlanEndDate() : DEFAULT_PLAN_END_DATE;
        if (planEndDate.isBefore(req.getData())) {
            throw new IllegalArgumentException("Data końca planu nie może być wcześniejsza niż data pierwszego przeglądu");
        }

        Harmonogram first = new Harmonogram();
        first.setData(req.getData());
        first.setOpis(req.getOpis());
        first.setDurationMinutes(req.getDurationMinutes());
        first.setMaszyna(maszyna);
        first.setOsoba(osoba);
        first.setDzial(dzial);
        first.setStatus(req.getStatus() != null ? req.getStatus() : StatusHarmonogramu.PLANOWANE);
        first.setFrequency(req.getFrequency());
        first.setPlanEndDate(planEndDate);

        final String seriesId = req.getFrequency() != null ? UUID.randomUUID().toString() : null;
        first.setSeriesId(seriesId);

        List<Harmonogram> toSave = new ArrayList<>();
        toSave.add(first);
        if (req.getFrequency() != null) {
            LocalDate nextDate = first.getData();
            while (true) {
                nextDate = nextDate(nextDate, req.getFrequency());
                if (nextDate.isAfter(planEndDate)) break;
                Harmonogram generated = cloneForSeries(first, nextDate, StatusHarmonogramu.PLANOWANE);
                toSave.add(generated);
            }
        }

        harmonogramRepository.saveAll(toSave);

        Harmonogram h = first;

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
    @Transactional
    public HarmonogramDTO update(@PathVariable Long id, @Valid @RequestBody HarmonogramUpdateRequest req) {
        Harmonogram h = harmonogramRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Harmonogram not found"));

        final boolean applyToSeriesFuture = Boolean.TRUE.equals(req.getApplyToSeriesFuture());
        final LocalDate originalDate = h.getData();
        
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
        if (req.getPlanEndDate() != null) {
            h.setPlanEndDate(req.getPlanEndDate());
        }

        if (h.getPlanEndDate() == null) {
            h.setPlanEndDate(DEFAULT_PLAN_END_DATE);
        }
        if (h.getData() != null && h.getPlanEndDate().isBefore(h.getData())) {
            throw new IllegalArgumentException("Data końca planu nie może być wcześniejsza niż data przeglądu");
        }

        harmonogramRepository.save(h);

        if (applyToSeriesFuture && h.getSeriesId() != null && !h.getSeriesId().isBlank() && h.getFrequency() != null) {
            final List<Harmonogram> futurePlanned = harmonogramRepository
                    .findBySeriesIdAndDataGreaterThanEqualAndStatus(h.getSeriesId(), originalDate, StatusHarmonogramu.PLANOWANE)
                    .stream()
                    .filter(item -> !item.getId().equals(h.getId()))
                    .collect(Collectors.toList());

            if (!futurePlanned.isEmpty()) {
                harmonogramRepository.deleteAll(futurePlanned);
            }

            List<Harmonogram> regenerated = new ArrayList<>();
            LocalDate next = h.getData();
            while (true) {
                next = nextDate(next, h.getFrequency());
                if (next.isAfter(h.getPlanEndDate())) break;
                regenerated.add(cloneForSeries(h, next, StatusHarmonogramu.PLANOWANE));
            }
            if (!regenerated.isEmpty()) {
                harmonogramRepository.saveAll(regenerated);
            }
        }

        return toDto(h);
    }

    @PostMapping("/{id}/complete")
    @Transactional
    public LinkedHashMap<String, Object> complete(@PathVariable Long id) {
        Harmonogram h = harmonogramRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Harmonogram not found"));

        h.setStatus(StatusHarmonogramu.ZAKONCZONE);
        harmonogramRepository.save(h);

        boolean planFinished = false;
        if (h.getSeriesId() != null && !h.getSeriesId().isBlank() && h.getData() != null) {
            long futureCount = harmonogramRepository.countBySeriesIdAndDataAfter(h.getSeriesId(), h.getData());
            planFinished = futureCount == 0;
        }

        LinkedHashMap<String, Object> result = new LinkedHashMap<>();
        result.put("id", h.getId());
        result.put("status", h.getStatus());
        result.put("planFinished", planFinished);
        if (planFinished) {
            result.put("message", "Plan przeglądów zakończony");
        }
        return result;
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
        dto.setSeriesId(h.getSeriesId());
        dto.setPlanEndDate(h.getPlanEndDate());
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
            if (h.getMaszyna().getDzial() != null) {
                SimpleDzialDTO d = new SimpleDzialDTO();
                d.setId(h.getMaszyna().getDzial().getId());
                d.setNazwa(h.getMaszyna().getDzial().getNazwa());
                maszynaDto.setDzial(d);
            }
            if (h.getMaszyna().getSekcja() != null) {
                SimpleSekcjaDTO s = new SimpleSekcjaDTO();
                s.setId(h.getMaszyna().getSekcja().getId());
                s.setNazwa(h.getMaszyna().getSekcja().getNazwa());
                maszynaDto.setSekcja(s);
            }
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

    private Harmonogram cloneForSeries(Harmonogram source, LocalDate date, StatusHarmonogramu status) {
        Harmonogram clone = new Harmonogram();
        clone.setData(date);
        clone.setOpis(source.getOpis());
        clone.setMaszyna(source.getMaszyna());
        clone.setOsoba(source.getOsoba());
        clone.setDzial(source.getDzial());
        clone.setDurationMinutes(source.getDurationMinutes());
        clone.setFrequency(source.getFrequency());
        clone.setSeriesId(source.getSeriesId());
        clone.setPlanEndDate(source.getPlanEndDate());
        clone.setStatus(status);
        return clone;
    }

    private LocalDate nextDate(LocalDate current, drimer.drimain.model.enums.HarmonogramOkres frequency) {
        return switch (frequency) {
            case TYGODNIOWY -> current.plusWeeks(1);
            case MIESIECZNY -> current.plusMonths(1);
            case KWARTALNY -> current.plusMonths(3);
            case POLROCZNY -> current.plusMonths(6);
            case ROCZNY -> current.plusYears(1);
        };
    }
}