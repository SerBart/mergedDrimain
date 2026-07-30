package drimer.drimain.api.mapper;

import drimer.drimain.api.dto.*;
import drimer.drimain.model.Part;
import drimer.drimain.model.PartUsage;
import drimer.drimain.model.Raport;
import drimer.drimain.model.enums.RaportStatus;
import drimer.drimain.repository.MaszynaRepository;
import drimer.drimain.repository.OsobaRepository;
import drimer.drimain.repository.PartRepository;
import drimer.drimain.util.RaportStatusMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.stream.Collectors;
import lombok.extern.slf4j.Slf4j;

@Component
@RequiredArgsConstructor
@Slf4j
public class RaportMapper {

    private final MaszynaRepository maszynaRepository;
    private final OsobaRepository osobaRepository;
    private final PartRepository partRepository;

    public RaportDTO toDto(Raport r) {
        if (r == null) return null;
        RaportDTO dto = new RaportDTO();
        try {
            dto.setId(r.getId());
        } catch (Exception e) {
            log.warn("Failed to map raport.id", e);
        }

        try {
            if (r.getMaszyna() != null) {
                SimpleMaszynaDTO m = new SimpleMaszynaDTO();
                m.setId(r.getMaszyna().getId());
                m.setNazwa(r.getMaszyna().getNazwa());
                if (r.getMaszyna().getDzial() != null) {
                    SimpleDzialDTO d = new SimpleDzialDTO();
                    d.setId(r.getMaszyna().getDzial().getId());
                    d.setNazwa(r.getMaszyna().getDzial().getNazwa());
                    m.setDzial(d);
                }
                dto.setMaszyna(m);
            }
        } catch (Exception e) {
            log.warn("Failed to map raport.maszyna", e);
            dto.setMaszyna(null);
        }

        try {
            if (r.getOsoba() != null) {
                SimpleOsobaDTO o = new SimpleOsobaDTO();
                o.setId(r.getOsoba().getId());
                o.setImieNazwisko(r.getOsoba().getImieNazwisko());
                dto.setOsoba(o);
            }
        } catch (Exception e) {
            log.warn("Failed to map raport.osoba", e);
            dto.setOsoba(null);
        }

        try {
            dto.setTypNaprawy(r.getTypNaprawy());
        } catch (Exception e) {
            log.warn("Failed to map raport.typNaprawy", e);
        }

        try {
            dto.setOpis(r.getOpis());
        } catch (Exception e) {
            log.warn("Failed to map raport.opis", e);
        }

        try {
            dto.setStatus(r.getStatus() != null ? r.getStatus().name() : null);
        } catch (Exception e) {
            log.warn("Failed to map raport.status", e);
        }

        try {
            dto.setDataNaprawy(r.getDataNaprawy());
        } catch (Exception e) {
            log.warn("Failed to map raport.dataNaprawy", e);
        }

        try {
            dto.setCzasOd(r.getCzasOd() != null ? r.getCzasOd().toString() : null);
        } catch (Exception e) {
            log.warn("Failed to map raport.czasOd", e);
        }

        try {
            dto.setCzasDo(r.getCzasDo() != null ? r.getCzasDo().toString() : null);
        } catch (Exception e) {
            log.warn("Failed to map raport.czasDo", e);
        }

        try {
            dto.setPartUsages(mapPartUsages(r.getPartUsages()));
        } catch (Exception e) {
            log.warn("Failed to map raport.partUsages", e);
            dto.setPartUsages(Collections.emptyList());
        }

        try {
            dto.setZdjecia(r.getZdjecia() != null ? new ArrayList<>(r.getZdjecia()) : Collections.emptyList());
        } catch (Exception e) {
            log.warn("Failed to map raport.zdjecia", e);
            dto.setZdjecia(Collections.emptyList());
        }

        return dto;
    }

    private java.util.List<PartUsageDTO> mapPartUsages(java.util.Set<PartUsage> partUsages) {
        if (partUsages == null) {
            return Collections.emptyList();
        }

        return partUsages.stream()
                .map(pu -> {
                    try {
                        if (pu == null) return null;
                        PartUsageDTO pud = new PartUsageDTO();
                        if (pu.getPart() != null) {
                            pud.setPartId(pu.getPart().getId());
                        }
                        pud.setIlosc(pu.getIlosc());
                        return pud;
                    } catch (Exception e) {
                        log.warn("Failed to map part usage", e);
                        return null;
                    }
                })
                .filter(pud -> pud != null)
                .collect(Collectors.toList());
    }


    public void applyPartUsages(Raport r, java.util.List<PartUsageDTO> list) {
        if (list == null) return;
        r.getPartUsages().clear();
        list.forEach(dto -> {
            Part part = partRepository.findById(dto.getPartId())
                    .orElseThrow(() -> new IllegalArgumentException("Part not found: " + dto.getPartId()));
            PartUsage pu = new PartUsage();
            pu.setPart(part);
            pu.setIlosc(dto.getIlosc());
            r.addPartUsage(pu);
        });
    }

    public void updateEntity(Raport r, RaportUpdateRequest req) {
        if (req.getTypNaprawy() != null) r.setTypNaprawy(req.getTypNaprawy());
        if (req.getOpis() != null) r.setOpis(req.getOpis());
        if (req.getStatus() != null) {
            RaportStatus mapped = RaportStatusMapper.map(req.getStatus());
            if (mapped != null) r.setStatus(mapped);
        }
        if (req.getDataNaprawy() != null) r.setDataNaprawy(req.getDataNaprawy());
        if (req.getCzasOd() != null) r.setCzasOd(parseTime(req.getCzasOd()));
        if (req.getCzasDo() != null) r.setCzasDo(parseTime(req.getCzasDo()));
        if (req.getMaszynaId() != null)
            r.setMaszyna(maszynaRepository.findById(req.getMaszynaId()).orElse(null));
        if (req.getOsobaId() != null)
            r.setOsoba(osobaRepository.findById(req.getOsobaId()).orElse(null));
        if (req.getPartUsages() != null) applyPartUsages(r, req.getPartUsages());
    }

    public void applyCreateDefaults(Raport r, RaportCreateRequest req) {
        if (req.getStatus() != null) {
            RaportStatus st = RaportStatusMapper.map(req.getStatus());
            r.setStatus(st != null ? st : RaportStatus.NOWY);
        } else {
            r.setStatus(RaportStatus.NOWY);
        }
    }

    // Elastyczne parsowanie czasu: akceptuj "8:00", "08:00", opcjonalne sekundy
    public LocalTime parseTime(String raw) {
        if (raw == null) return null;
        String s = raw.trim();
        if (s.isEmpty()) return null;
        DateTimeFormatter[] patterns = new DateTimeFormatter[] {
                DateTimeFormatter.ofPattern("H:mm"),
                DateTimeFormatter.ofPattern("HH:mm"),
                DateTimeFormatter.ofPattern("H:mm:ss"),
                DateTimeFormatter.ofPattern("HH:mm:ss")
        };
        for (DateTimeFormatter f : patterns) {
            try { return LocalTime.parse(s, f); } catch (DateTimeParseException ignored) {}
        }
        throw new IllegalArgumentException("Invalid time format: '" + raw + "'. Expected HH:mm or HH:mm:ss");
    }
}