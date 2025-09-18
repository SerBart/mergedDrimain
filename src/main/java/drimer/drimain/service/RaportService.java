package drimer.drimain.service;

import drimer.drimain.api.dto.PartUsageDTO;
import drimer.drimain.api.dto.RaportCreateRequest;
import drimer.drimain.api.dto.RaportUpdateRequest;
import drimer.drimain.model.Part;
import drimer.drimain.model.PartUsage;
import drimer.drimain.model.Raport;
import drimer.drimain.model.enums.RaportStatus;
import drimer.drimain.repository.MaszynaRepository;
import drimer.drimain.repository.OsobaRepository;
import drimer.drimain.repository.PartRepository;
import drimer.drimain.repository.PartUsageRepository;
import drimer.drimain.repository.RaportRepository;
import drimer.drimain.util.RaportStatusMapper;
import jakarta.transaction.Transactional;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class RaportService {

    private final RaportRepository raportRepository;
    private final MaszynaRepository maszynaRepository;
    private final OsobaRepository osobaRepository;
    private final PartRepository partRepository;
    private final PartUsageRepository partUsageRepository;

    @Transactional
    public Raport create(RaportCreateRequest req) {
        Raport r = new Raport();
        applyCreate(r, req);
        raportRepository.save(r);
        savePartUsages(r, req.getPartUsages());
        return r;
    }

    @Transactional
    public Raport update(Long id, RaportUpdateRequest req) {
        Raport r = raportRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Raport not found"));
        applyUpdate(r, req);
        raportRepository.save(r);
        // Reset użyć części – w prostym wariancie kasujemy i dodajemy ponownie
        if (req.getPartUsages() != null) {
            partUsageRepository.deleteAll(r.getPartUsages());
            savePartUsages(r, req.getPartUsages());
        }
        return r;
    }

    public Raport get(Long id) {
        return raportRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Raport not found"));
    }

    public List<Raport> all() {
        return raportRepository.findAll();
    }

    public void delete(Long id) {
        raportRepository.deleteById(id);
    }

    /* ================== PRIVATE ================== */

    private void applyCreate(Raport r, RaportCreateRequest req) {
        r.setTypNaprawy(req.getTypNaprawy());
        r.setOpis(req.getOpis());

        // Status z mapowaniem – bezpieczny na null / stare nazwy
        RaportStatus mapped = RaportStatusMapper.map(req.getStatus());
        r.setStatus(mapped != null ? mapped : RaportStatus.NOWY);

        r.setDataNaprawy(req.getDataNaprawy());
        if (req.getCzasOd() != null && !req.getCzasOd().isBlank())
            r.setCzasOd(LocalTime.parse(req.getCzasOd()));
        if (req.getCzasDo() != null && !req.getCzasDo().isBlank())
            r.setCzasDo(LocalTime.parse(req.getCzasDo()));

        if (req.getMaszynaId() != null) {
            r.setMaszyna(maszynaRepository.findById(req.getMaszynaId()).orElse(null));
        }
        if (req.getOsobaId() != null) {
            r.setOsoba(osobaRepository.findById(req.getOsobaId()).orElse(null));
        }
    }

    private void applyUpdate(Raport r, RaportUpdateRequest req) {
        if (req.getTypNaprawy() != null) r.setTypNaprawy(req.getTypNaprawy());
        if (req.getOpis() != null) r.setOpis(req.getOpis());
        if (req.getStatus() != null) {
            RaportStatus mapped = RaportStatusMapper.map(req.getStatus());
            if (mapped != null) r.setStatus(mapped);
        }
        if (req.getDataNaprawy() != null) r.setDataNaprawy(req.getDataNaprawy());
        if (req.getCzasOd() != null && !req.getCzasOd().isBlank())
            r.setCzasOd(LocalTime.parse(req.getCzasOd()));
        if (req.getCzasDo() != null && !req.getCzasDo().isBlank())
            r.setCzasDo(LocalTime.parse(req.getCzasDo()));
        if (req.getMaszynaId() != null)
            r.setMaszyna(maszynaRepository.findById(req.getMaszynaId()).orElse(null));
        if (req.getOsobaId() != null)
            r.setOsoba(osobaRepository.findById(req.getOsobaId()).orElse(null));
    }

    private void savePartUsages(Raport raport, List<PartUsageDTO> partUsages) {
        if (partUsages == null || partUsages.isEmpty()) return;
        for (PartUsageDTO dto : partUsages) {
            Part part = partRepository.findById(dto.getPartId())
                    .orElseThrow(() -> new IllegalArgumentException("Part not found: " + dto.getPartId()));
            PartUsage pu = new PartUsage();
            pu.setRaport(raport);
            pu.setPart(part);
            pu.setIlosc(dto.getIlosc());
            partUsageRepository.save(pu);
        }
    }
}