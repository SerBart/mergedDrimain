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
import java.util.Collections;
import java.util.stream.Collectors;

@Component
@RequiredArgsConstructor
public class RaportMapper {

    private final MaszynaRepository maszynaRepository;
    private final OsobaRepository osobaRepository;
    private final PartRepository partRepository;

    public RaportDTO toDto(Raport r) {
        RaportDTO dto = new RaportDTO();
        dto.setId(r.getId());
        if (r.getMaszyna() != null) {
            SimpleMaszynaDTO m = new SimpleMaszynaDTO();
            m.setId(r.getMaszyna().getId());
            m.setNazwa(r.getMaszyna().getNazwa());
            dto.setMaszyna(m);
        }
        if (r.getOsoba() != null) {
            SimpleOsobaDTO o = new SimpleOsobaDTO();
            o.setId(r.getOsoba().getId());
            o.setImieNazwisko(r.getOsoba().getImieNazwisko());
            dto.setOsoba(o);
        }
        dto.setTypNaprawy(r.getTypNaprawy());
        dto.setOpis(r.getOpis());
        dto.setStatus(r.getStatus() != null ? r.getStatus().name() : null);
        dto.setDataNaprawy(r.getDataNaprawy());
        dto.setCzasOd(r.getCzasOd() != null ? r.getCzasOd().toString() : null);
        dto.setCzasDo(r.getCzasDo() != null ? r.getCzasDo().toString() : null);
        dto.setPartUsages(r.getPartUsages() != null
                ? r.getPartUsages().stream().map(pu -> {
            PartUsageDTO pud = new PartUsageDTO();
            pud.setPartId(pu.getPart().getId());
            pud.setIlosc(pu.getIlosc());
            return pud;
        }).collect(Collectors.toList())
                : Collections.emptyList());
        return dto;
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
        if (req.getCzasOd() != null) r.setCzasOd(LocalTime.parse(req.getCzasOd()));
        if (req.getCzasDo() != null) r.setCzasDo(LocalTime.parse(req.getCzasDo()));
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
}